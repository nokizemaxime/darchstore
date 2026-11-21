/// Contrat Firestore / Storage partagé avec le back-office React.
///
/// Les clients ne peuvent pas écrire dans `apps` ni dans Storage.
/// Seul un jeton Firebase `admin: true` passe les règles d’administration.
abstract final class Schema {
  static const apps = 'apps';
  static const versions = 'versions';
  static const statsEvents = 'stats_events';
  static const devices = 'devices';

  static const name = 'name';
  static const nameLower = 'nameLower';
  static const packageName = 'packageName';
  static const summary = 'summary';
  static const description = 'description';
  static const iconUrl = 'iconUrl';
  static const category = 'category';
  static const developerName = 'developerName';
  static const websiteUrl = 'websiteUrl';
  static const published = 'published';
  static const featured = 'featured';
  static const latestVersionCode = 'latestVersionCode';
  static const latestVersionName = 'latestVersionName';
  static const releaseNotes = 'releaseNotes';
  static const apkStoragePath = 'apkStoragePath';
  static const sha256 = 'sha256';
  static const signatureSha256 = 'signatureSha256';
  static const sizeBytes = 'sizeBytes';
  static const minSdk = 'minSdk';
  static const mandatory = 'mandatory';
  static const downloadCount = 'downloadCount';
  static const updatedAt = 'updatedAt';
  static const createdAt = 'createdAt';

  static const versionCode = 'versionCode';
  static const versionName = 'versionName';

  static const appId = 'appId';
  static const type = 'type';
  static const deviceId = 'deviceId';
  static const storeVersion = 'storeVersion';
  static const appsMap = 'apps';

  static const updateTopic = 'darchstore-updates';
  static const notificationChannelId = 'darchstore_updates';
}
