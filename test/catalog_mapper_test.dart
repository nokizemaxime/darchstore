import 'package:darchstore/core/security/policies.dart';
import 'package:darchstore/features/catalog/data/store_app_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepte uniquement un apk publié dans le dossier de l’application', () {
    expect(StoragePathPolicy.allows('releases/atlas/3.apk'), isTrue);
    expect(StoragePathPolicy.allows('releases/../secret.apk'), isFalse);
    expect(StoragePathPolicy.allows('https://example.com/app.apk'), isFalse);
    expect(HttpsUrlPolicy.sanitize('http://example.com/icon.png'), isNull);
    expect(
      HttpsUrlPolicy.sanitize('https://cdn.example.com/icon.png'),
      'https://cdn.example.com/icon.png',
    );
  });

  test('ignore un document incomplet ou non publié', () {
    expect(mapStoreApp('atlas', _valid(published: false)), isNull);
    expect(mapStoreApp('atlas', _valid(packageName: 'pas un paquet')), isNull);
    expect(mapStoreApp('atlas', _valid(path: 'releases/autre/3.apk')), isNull);
    expect(mapStoreApp('atlas', _valid())?.name, 'Atlas Notes');
  });
}

Map<String, Object?> _valid({
  bool published = true,
  String packageName = 'com.darch.atlas',
  String path = 'releases/atlas/3.apk',
}) {
  return {
    'published': published,
    'name': 'Atlas Notes',
    'packageName': packageName,
    'summary': 'Notes',
    'description': 'Description',
    'category': 'Outils',
    'developerName': 'Darch',
    'latestVersionName': '1.2.0',
    'latestVersionCode': 3,
    'releaseNotes': 'Corrections',
    'apkStoragePath': path,
    'sha256': 'a' * 64,
    'signatureSha256': 'b' * 64,
    'sizeBytes': 2048,
    'minSdk': 24,
    'mandatory': false,
    'featured': false,
    'downloadCount': 4,
    'updatedAt': DateTime.utc(2026, 5, 1),
  };
}
