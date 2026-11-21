import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/domain/catalog_logic.dart';
import '../../catalog/domain/models.dart';
import '../data/device_repository.dart';
import '../domain/installed_package.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(isReady: () => ref.read(firebaseReadyProvider));
});

final installedAppsProvider = FutureProvider<Map<String, InstalledPackage>>((
  ref,
) async {
  final catalog = await ref.watch(catalogProvider.future);
  final names = catalog.apps.map((app) => app.packageName).toList();
  if (names.isEmpty) return const {};
  return ref.watch(packageBridgeProvider).getInstalled(names);
});

final updateCountProvider = Provider<int>((ref) {
  final apps = ref.watch(catalogProvider).valueOrNull?.apps;
  final installed = ref.watch(installedAppsProvider).valueOrNull;
  if (apps == null || installed == null) return 0;
  return availableUpdates(apps, installed).length;
});

final libraryAppsProvider = Provider<List<StoreApp>>((ref) {
  final apps = ref.watch(catalogProvider).valueOrNull?.apps;
  final installed = ref.watch(installedAppsProvider).valueOrNull;
  if (apps == null || installed == null) return const [];
  return installedCatalogApps(apps, installed);
});

final updatesProvider = Provider<List<StoreApp>>((ref) {
  final apps = ref.watch(catalogProvider).valueOrNull?.apps;
  final installed = ref.watch(installedAppsProvider).valueOrNull;
  if (apps == null || installed == null) return const [];
  return availableUpdates(apps, installed);
});

final deviceSyncProvider = Provider<void>((ref) {
  ref.listen(installedAppsProvider, (_, next) {
    final apps = next.valueOrNull;
    if (apps == null) return;
    ref.read(deviceRepositoryProvider).sync(apps);
  });
});
