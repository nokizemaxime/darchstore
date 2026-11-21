import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/installed_package.dart';
import '../domain/package_bridge.dart';

class PlatformPackageBridge implements PackageBridge {
  static const _methods = MethodChannel('com.example.darchstore/packages');
  static const _events = EventChannel('com.example.darchstore/install_events');

  Stream<InstallEvent>? _eventsStream;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<InstallEvent> get events {
    if (!_isAndroid) return const Stream<InstallEvent>.empty();
    return _eventsStream ??= _events
        .receiveBroadcastStream()
        .map(InstallEvent.parse)
        .where((event) => event != null)
        .map((event) => event!);
  }

  @override
  Future<Map<String, InstalledPackage>> getInstalled(
    List<String> packageNames,
  ) async {
    if (!_isAndroid || packageNames.isEmpty) return const {};
    final raw = await _methods.invokeMethod<List<dynamic>>('getInstalled', {
      'packages': packageNames,
    });
    final result = <String, InstalledPackage>{};
    for (final item in raw ?? const []) {
      final parsed = _parseInstalled(item);
      if (parsed != null) result[parsed.packageName] = parsed;
    }
    return result;
  }

  @override
  Future<int> deviceSdk() async {
    if (!_isAndroid) return 0;
    final sdk = await _methods.invokeMethod<int>('deviceSdk');
    return sdk ?? 0;
  }

  @override
  Future<bool> canRequestInstalls() async {
    if (!_isAndroid) return false;
    return await _methods.invokeMethod<bool>('canRequestInstalls') ?? false;
  }

  @override
  Future<bool> openInstallPermissionSettings() async {
    if (!_isAndroid) return false;
    return await _methods.invokeMethod<bool>('openInstallSettings') ?? false;
  }

  @override
  Future<bool> openApp(String packageName) async {
    if (!_isAndroid) return false;
    return await _methods.invokeMethod<bool>('openApp', {
          'packageName': packageName,
        }) ??
        false;
  }

  @override
  Future<String?> readArchiveSignature(String path) async {
    if (!_isAndroid) return null;
    return _methods.invokeMethod<String>('readArchiveSignature', {
      'path': path,
    });
  }

  @override
  Future<void> installApk({
    required String path,
    required String packageName,
    required int versionCode,
  }) async {
    if (!_isAndroid) {
      throw PlatformException(
        code: 'UNSUPPORTED',
        message: 'L’installation est disponible sur Android.',
      );
    }
    await _methods.invokeMethod<void>('installApk', {
      'path': path,
      'packageName': packageName,
      'versionCode': versionCode,
    });
  }

  InstalledPackage? _parseInstalled(Object? raw) {
    if (raw is! Map) return null;
    if (raw['installed'] != true) return null;
    final packageName = raw['packageName'];
    final versionCode = raw['versionCode'];
    if (packageName is! String || versionCode is! num) return null;
    final versionName = raw['versionName'];
    final signature = raw['signatureSha256'];
    return InstalledPackage(
      packageName: packageName,
      versionName: versionName is String ? versionName : '',
      versionCode: versionCode.toInt(),
      signatureSha256: signature is String ? signature.toLowerCase() : '',
    );
  }
}
