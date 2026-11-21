import 'installed_package.dart';

abstract class PackageBridge {
  Stream<InstallEvent> get events;

  Future<Map<String, InstalledPackage>> getInstalled(List<String> packageNames);

  Future<int> deviceSdk();

  Future<bool> canRequestInstalls();

  Future<bool> openInstallPermissionSettings();

  Future<bool> openApp(String packageName);

  Future<String?> readArchiveSignature(String path);

  Future<void> installApk({
    required String path,
    required String packageName,
    required int versionCode,
  });
}
