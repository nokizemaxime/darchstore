package com.example.darchstore

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        val packageName = intent.getStringExtra(EXTRA_PACKAGE)
            ?: intent.getStringExtra(PackageInstaller.EXTRA_PACKAGE_NAME)
            ?: ""
        val systemMessage = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE).orEmpty()

        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                }
                StorePackageBridge.emit(
                    mapOf(
                        "packageName" to packageName,
                        "status" to "awaiting_user",
                    ),
                )
            }

            PackageInstaller.STATUS_SUCCESS -> {
                StorePackageBridge.emit(
                    mapOf(
                        "packageName" to packageName,
                        "status" to "success",
                    ),
                )
            }

            PackageInstaller.STATUS_FAILURE_ABORTED -> {
                StorePackageBridge.emit(
                    mapOf(
                        "packageName" to packageName,
                        "status" to "cancelled",
                        "message" to "Installation annulée",
                    ),
                )
            }

            else -> {
                StorePackageBridge.emit(
                    mapOf(
                        "packageName" to packageName,
                        "status" to "failure",
                        "message" to systemMessage.ifBlank { "L'installation a échoué." },
                    ),
                )
            }
        }
    }
}
