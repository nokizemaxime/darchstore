import 'package:darchstore/app/darch_app.dart';
import 'package:darchstore/app/dependencies.dart';
import 'package:darchstore/features/catalog/domain/catalog_repository.dart';
import 'package:darchstore/features/catalog/domain/models.dart';
import 'package:darchstore/features/device/domain/installed_package.dart';
import 'package:darchstore/features/device/domain/package_bridge.dart';
import 'package:darchstore/features/library/presentation/library_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('le catalogue public s’ouvre sans connexion', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          notificationsEnabledProvider.overrideWithValue(false),
          catalogRepositoryProvider.overrideWithValue(
            FakeCatalogRepository([_atlas]),
          ),
          packageBridgeProvider.overrideWithValue(FakePackageBridge()),
          storeVersionProvider.overrideWith((ref) async => '1.0.0'),
        ],
        child: const DarchApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atlas Notes'), findsOneWidget);
    expect(find.text('Catalogue'), findsWidgets);

    await tester.tap(find.text('Atlas Notes'));
    await tester.pumpAndSettle();

    expect(find.text('Notes de terrain'), findsOneWidget);
    expect(find.text('Installer'), findsOneWidget);
  });
}

final _atlas = StoreApp(
  id: 'atlas',
  name: 'Atlas Notes',
  packageName: 'com.darch.atlas',
  summary: 'Notes de terrain',
  description: 'Carnet hors ligne.',
  category: 'Outils',
  developerName: 'Darch',
  latestVersionName: '1.2.0',
  latestVersionCode: 3,
  releaseNotes: 'Corrections',
  apkStoragePath: 'releases/atlas/3.apk',
  sha256: 'a' * 64,
  signatureSha256: 'b' * 64,
  sizeBytes: 2048,
  minSdk: 24,
  mandatory: false,
  featured: false,
  downloadCount: 4,
  updatedAt: DateTime.utc(2026, 5, 1),
);

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository(this.apps);

  final List<StoreApp> apps;

  @override
  Future<CatalogBatch> fetchPublished({
    int limit = 40,
    String? startAfterId,
  }) async {
    return CatalogBatch(apps: apps, hasMore: false);
  }

  @override
  Future<StoreApp?> fetchById(String id) async {
    return apps.where((app) => app.id == id).firstOrNull;
  }

  @override
  Future<List<AppRelease>> fetchReleases(String appId, {int limit = 15}) async {
    return const [];
  }
}

class FakePackageBridge implements PackageBridge {
  @override
  Stream<InstallEvent> get events => const Stream<InstallEvent>.empty();

  @override
  Future<bool> canRequestInstalls() async => false;

  @override
  Future<int> deviceSdk() async => 34;

  @override
  Future<Map<String, InstalledPackage>> getInstalled(
    List<String> packageNames,
  ) async {
    return const {};
  }

  @override
  Future<void> installApk({
    required String path,
    required String packageName,
    required int versionCode,
  }) async {}

  @override
  Future<bool> openApp(String packageName) async => false;

  @override
  Future<bool> openInstallPermissionSettings() async => false;

  @override
  Future<String?> readArchiveSignature(String path) async => null;
}
