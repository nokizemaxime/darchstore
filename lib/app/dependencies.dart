import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/data/firestore_catalog_repository.dart';
import '../features/catalog/data/unconfigured_catalog_repository.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/device/data/platform_package_bridge.dart';
import '../features/device/domain/package_bridge.dart';
import '../features/install/data/apk_downloader.dart';

final firebaseReadyProvider = Provider<bool>((ref) => false);

final notificationsEnabledProvider = Provider<bool>((ref) => true);

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  if (!ref.watch(firebaseReadyProvider)) {
    return const UnconfiguredCatalogRepository();
  }
  return FirestoreCatalogRepository(FirebaseFirestore.instance);
});

final packageBridgeProvider = Provider<PackageBridge>((ref) {
  return PlatformPackageBridge();
});

final apkDownloaderProvider = Provider<ApkDownloader>((ref) {
  if (!ref.watch(firebaseReadyProvider)) {
    return const UnavailableApkDownloader();
  }
  return StorageApkDownloader(FirebaseStorage.instance);
});
