import 'package:darchstore/core/security/policies.dart';
import 'package:darchstore/features/catalog/domain/catalog_logic.dart';
import 'package:darchstore/features/catalog/domain/models.dart';
import 'package:darchstore/features/device/domain/installed_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StoreApp app({int versionCode = 3, int minSdk = 24, String signature = ''}) {
    return StoreApp(
      id: 'atlas',
      name: 'Atlas',
      packageName: 'com.darch.atlas',
      summary: '',
      description: '',
      category: 'Outils',
      developerName: 'Darch',
      latestVersionName: '1.$versionCode.0',
      latestVersionCode: versionCode,
      releaseNotes: '',
      apkStoragePath: 'releases/atlas/$versionCode.apk',
      sha256: 'a' * 64,
      signatureSha256: signature,
      sizeBytes: 10,
      minSdk: minSdk,
      mandatory: false,
      featured: false,
      downloadCount: 0,
      updatedAt: DateTime.utc(2026, 3, 1),
    );
  }

  test('une application absente peut être installée', () {
    final decision = UpdatePolicy.decide(
      installedVersionCode: null,
      remoteVersionCode: 2,
      installedCertSha256: null,
      remoteCertSha256: '',
      deviceSdk: 34,
      minSdk: 24,
    );
    expect(decision, UpdateDecision.install);
  });

  test('une version identique est à jour', () {
    final decision = UpdatePolicy.decide(
      installedVersionCode: 4,
      remoteVersionCode: 4,
      installedCertSha256: 'aa' * 32,
      remoteCertSha256: 'aa' * 32,
      deviceSdk: 34,
      minSdk: 24,
    );
    expect(decision, UpdateDecision.upToDate);
  });

  test('un retour arrière est bloqué', () {
    final decision = UpdatePolicy.decide(
      installedVersionCode: 5,
      remoteVersionCode: 4,
      installedCertSha256: null,
      remoteCertSha256: '',
      deviceSdk: 34,
      minSdk: 24,
    );
    expect(decision, UpdateDecision.downgradeBlocked);
  });

  test('une signature différente bloque la mise à jour', () {
    final decision = UpdatePolicy.decide(
      installedVersionCode: 2,
      remoteVersionCode: 3,
      installedCertSha256: 'aa' * 32,
      remoteCertSha256: 'bb' * 32,
      deviceSdk: 34,
      minSdk: 24,
    );
    expect(decision, UpdateDecision.signatureMismatch);
    expect(decision.isBlocked, isTrue);
  });

  test('le même certificat autorise la mise à jour', () {
    final decision = UpdatePolicy.decide(
      installedVersionCode: 2,
      remoteVersionCode: 3,
      installedCertSha256: 'Ab' * 32,
      remoteCertSha256: 'ab' * 32,
      deviceSdk: 34,
      minSdk: 24,
    );
    expect(decision, UpdateDecision.update);
  });

  test('un Android trop ancien est refusé', () {
    final decision = UpdatePolicy.decide(
      installedVersionCode: null,
      remoteVersionCode: 1,
      installedCertSha256: null,
      remoteCertSha256: '',
      deviceSdk: 23,
      minSdk: 24,
    );
    expect(decision, UpdateDecision.incompatibleSdk);
  });

  test('la recherche ignore la casse et la catégorie filtre', () {
    final list = [
      app(versionCode: 1),
      StoreApp(
        id: 'brume',
        name: 'Brume',
        packageName: 'com.darch.brume',
        summary: 'Météo',
        description: '',
        category: 'Loisirs',
        developerName: 'Darch',
        latestVersionName: '2.0.0',
        latestVersionCode: 2,
        releaseNotes: '',
        apkStoragePath: 'releases/brume/2.apk',
        sha256: 'b' * 64,
        signatureSha256: '',
        sizeBytes: 10,
        minSdk: 24,
        mandatory: true,
        featured: true,
        downloadCount: 0,
        updatedAt: DateTime.utc(2026, 4, 1),
      ),
    ];
    final filtered = filterCatalog(
      list,
      const CatalogQuery(text: 'BRU', category: 'Loisirs'),
    );
    expect(filtered.map((item) => item.id), ['brume']);
    expect(
      availableUpdates(list, {
        'com.darch.brume': InstalledPackage(
          packageName: 'com.darch.brume',
          versionName: '1.0.0',
          versionCode: 1,
          signatureSha256: '',
        ),
      }).map((item) => item.id),
      ['brume'],
    );
  });

  test('les empreintes sont comparées sans fuite de longueur', () {
    expect(secureEqualsHex('AbC', 'abc'), isTrue);
    expect(secureEqualsHex('abcd', 'abc'), isFalse);
    expect(secureEqualsHex('aaaa', 'aaab'), isFalse);
  });
}
