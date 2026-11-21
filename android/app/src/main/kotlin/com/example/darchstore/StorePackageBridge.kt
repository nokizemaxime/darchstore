package com.example.darchstore

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

const val EXTRA_PACKAGE = "darchstore.package"
const val EXTRA_VERSION = "darchstore.version"

private const val TAG = "DarchStore"
private const val METHOD_CHANNEL = "com.example.darchstore/packages"
private const val EVENT_CHANNEL = "com.example.darchstore/install_events"
private const val MAX_APK_BYTES = 512L * 1024L * 1024L
private val PACKAGE_PATTERN =
    Regex("^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)+$")

class StorePackageBridge private constructor(
    private val activity: FlutterActivity,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalled" -> io.execute {
                val payload = readInstalled(call.argument<List<Any?>>("packages"))
                onMain { result.success(payload) }
            }

            "deviceSdk" -> result.success(Build.VERSION.SDK_INT)
            "canRequestInstalls" -> result.success(canRequestInstalls())
            "openInstallSettings" -> result.success(openInstallSettings())
            "openApp" -> result.success(openApp(call.argument<String>("packageName").orEmpty()))
            "readArchiveSignature" -> io.execute {
                val signature = readArchiveSignature(call.argument<String>("path").orEmpty())
                onMain { result.success(signature) }
            }

            "installApk" -> installApk(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun readInstalled(names: List<Any?>?): List<Map<String, Any?>> {
        if (names == null) return emptyList()
        val manager = activity.packageManager
        return names.mapNotNull { raw ->
            val packageName = raw as? String ?: return@mapNotNull null
            if (!PACKAGE_PATTERN.matches(packageName)) {
                return@mapNotNull mapOf("packageName" to packageName, "installed" to false)
            }
            try {
                val info = manager.getPackageInfo(packageName, signatureFlags())
                mapOf(
                    "packageName" to packageName,
                    "installed" to true,
                    "versionName" to info.versionName.orEmpty(),
                    "versionCode" to versionCodeOf(info),
                    "signatureSha256" to fingerprint(info).orEmpty(),
                )
            } catch (_: PackageManager.NameNotFoundException) {
                mapOf("packageName" to packageName, "installed" to false)
            } catch (error: Exception) {
                Log.w(TAG, "Paquet illisible", error)
                mapOf("packageName" to packageName, "installed" to false)
            }
        }
    }

    private fun readArchiveSignature(path: String): String? {
        val file = File(path)
        if (!isAllowedApk(file)) return null
        val info = activity.packageManager.getPackageArchiveInfo(path, signatureFlags()) ?: return null
        info.applicationInfo?.sourceDir = path
        info.applicationInfo?.publicSourceDir = path
        return fingerprint(info)
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val packageName = call.argument<String>("packageName")
        val versionCode = call.argument<Number>("versionCode")?.toLong()
        if (path.isNullOrBlank() || packageName.isNullOrBlank() || versionCode == null) {
            result.error("ARGUMENT", "Paramètres d'installation incomplets.", null)
            return
        }
        if (!PACKAGE_PATTERN.matches(packageName)) {
            result.error("ARGUMENT", "Nom de paquet refusé.", null)
            return
        }
        val file = File(path)
        if (!isAllowedApk(file) || file.length() <= 0L || file.length() > MAX_APK_BYTES || !hasZipHeader(file)) {
            result.error("PATH", "Fichier d'installation refusé.", null)
            return
        }
        if (!canRequestInstalls()) {
            result.error("PERMISSION", "Autorisez l'installation depuis cette application.", null)
            return
        }

        val replied = AtomicBoolean(false)
        fun replySuccess() {
            if (replied.compareAndSet(false, true)) result.success(null)
        }
        fun replyError(code: String, message: String) {
            if (replied.compareAndSet(false, true)) result.error(code, message, null)
        }

        io.execute {
            var session: PackageInstaller.Session? = null
            try {
                val installer = activity.packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
                params.setSize(file.length())
                if (Build.VERSION.SDK_INT >= 31) {
                    params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
                }
                val sessionId = installer.createSession(params)
                val opened = installer.openSession(sessionId)
                session = opened
                file.inputStream().use { input ->
                    opened.openWrite("darchstore.apk", 0, file.length()).use { output ->
                        input.copyTo(output)
                        opened.fsync(output)
                    }
                }
                val callback = Intent(activity, InstallResultReceiver::class.java).apply {
                    putExtra(EXTRA_PACKAGE, packageName)
                    putExtra(EXTRA_VERSION, versionCode)
                }
                val flags = if (Build.VERSION.SDK_INT >= 31) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pending = PendingIntent.getBroadcast(activity, sessionId, callback, flags)
                opened.commit(pending.intentSender)
                opened.close()
                session = null
                onMain { replySuccess() }
            } catch (error: Exception) {
                Log.w(TAG, "Session d'installation interrompue", error)
                try {
                    session?.abandon()
                } catch (abandonError: Exception) {
                    Log.w(TAG, "Session non abandonnée", abandonError)
                }
                onMain { replyError("INSTALL", "Impossible de lancer l'installation.") }
            }
        }
    }

    private fun canRequestInstalls(): Boolean {
        if (Build.VERSION.SDK_INT < 26) return true
        return activity.packageManager.canRequestPackageInstalls()
    }

    private fun openInstallSettings(): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        return try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}"),
            )
            activity.startActivity(intent)
            true
        } catch (error: Exception) {
            Log.w(TAG, "Paramètres d'installation indisponibles", error)
            false
        }
    }

    private fun openApp(packageName: String): Boolean {
        if (!PACKAGE_PATTERN.matches(packageName)) return false
        val launch = activity.packageManager.getLaunchIntentForPackage(packageName) ?: return false
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            activity.startActivity(launch)
            true
        } catch (error: Exception) {
            Log.w(TAG, "Ouverture impossible", error)
            false
        }
    }

    private fun isAllowedApk(file: File): Boolean {
        if (!file.isFile || !file.name.endsWith(".apk", ignoreCase = true)) return false
        val child = try {
            file.canonicalFile
        } catch (_: Exception) {
            return false
        }
        val roots = listOf(
            File(activity.cacheDir, "apk"),
            File(activity.filesDir, "apk"),
        )
        return roots.any { root ->
            val parent = root.canonicalFile.path + File.separator
            child.path.startsWith(parent)
        }
    }

    private fun hasZipHeader(file: File): Boolean {
        return try {
            file.inputStream().use { input ->
                val header = ByteArray(2)
                input.read(header) == 2 && header[0] == 0x50.toByte() && header[1] == 0x4B.toByte()
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun signatureFlags(): Int {
        return if (Build.VERSION.SDK_INT >= 28) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
    }

    private fun versionCodeOf(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= 28) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun fingerprint(info: PackageInfo): String? {
        val signatures: Array<out Signature>? = if (Build.VERSION.SDK_INT >= 28) {
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        }
        if (signatures.isNullOrEmpty()) return null
        return signatures.map { signature ->
            MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString("") { byte -> "%02x".format(byte) }
        }.sorted().joinToString(",")
    }

    private fun onMain(block: () -> Unit) {
        Handler(Looper.getMainLooper()).post(block)
    }

    companion object {
        private val io = Executors.newSingleThreadExecutor()
        private var sink: EventChannel.EventSink? = null

        fun register(activity: FlutterActivity, messenger: BinaryMessenger) {
            val bridge = StorePackageBridge(activity)
            MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(bridge)
            EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(bridge)
        }

        fun unregister() {
            sink = null
        }

        fun emit(event: Map<String, Any?>) {
            Handler(Looper.getMainLooper()).post { sink?.success(event) }
        }
    }
}
