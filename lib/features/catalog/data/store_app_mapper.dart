import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/schema.dart';
import '../../../core/format/formatters.dart';
import '../../../core/security/policies.dart';
import '../domain/models.dart';

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.fromMillisecondsSinceEpoch(0);
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

String _text(Object? value, int max) {
  if (value is! String) return '';
  final trimmed = value.trim();
  if (trimmed.length <= max) return trimmed;
  return trimmed.substring(0, max);
}

StoreApp? mapStoreApp(String id, Map<String, dynamic> data) {
  try {
    if (!DocumentIdPolicy.allows(id) || data[Schema.published] != true) {
      return null;
    }
    final name = _text(data[Schema.name], 80);
    final packageName = _text(data[Schema.packageName], 200);
    final versionName = _text(data[Schema.latestVersionName], 40);
    final versionCode = _int(data[Schema.latestVersionCode], fallback: -1);
    final path = _text(data[Schema.apkStoragePath], 300);
    final sha = _text(data[Schema.sha256], 80).toLowerCase();
    final signature = _text(data[Schema.signatureSha256], 600).toLowerCase();
    final size = _int(data[Schema.sizeBytes]);
    if (name.isEmpty ||
        !PackageNamePolicy.allows(packageName) ||
        versionName.isEmpty ||
        versionCode < 1 ||
        !path.startsWith('releases/$id/') ||
        !StoragePathPolicy.allows(path) ||
        !DigestPolicy.isSha256(sha) ||
        (signature.isNotEmpty && !DigestPolicy.isSignature(signature)) ||
        size < 0 ||
        size > StoragePathPolicy.maxApkBytes) {
      return null;
    }
    final minSdk = _int(data[Schema.minSdk], fallback: 24);
    return StoreApp(
      id: id,
      name: name,
      packageName: packageName,
      summary: _text(data[Schema.summary], 180),
      description: _text(data[Schema.description], 8000),
      category: _text(data[Schema.category], 40).ifEmpty('Autres'),
      developerName: _text(
        data[Schema.developerName],
        80,
      ).ifEmpty('Indépendant'),
      latestVersionName: versionName,
      latestVersionCode: versionCode,
      releaseNotes: _text(data[Schema.releaseNotes], 4000),
      apkStoragePath: path,
      sha256: sha,
      signatureSha256: signature,
      sizeBytes: size,
      minSdk: minSdk < 1 ? 24 : minSdk,
      mandatory: data[Schema.mandatory] == true,
      featured: data[Schema.featured] == true,
      downloadCount: _int(data[Schema.downloadCount]).clamp(0, 1 << 30),
      updatedAt: _date(data[Schema.updatedAt]),
      iconUrl: HttpsUrlPolicy.sanitize(_text(data[Schema.iconUrl], 500)),
      websiteUrl: HttpsUrlPolicy.sanitize(_text(data[Schema.websiteUrl], 500)),
    );
  } catch (error, stack) {
    debugPrint('Application ignorée ($id): $error\n$stack');
    return null;
  }
}

AppRelease? mapRelease(String id, Map<String, dynamic> data) {
  if (data[Schema.published] != true) return null;
  final versionName = _text(data[Schema.versionName], 40);
  final versionCode = _int(data[Schema.versionCode], fallback: -1);
  if (versionName.isEmpty || versionCode < 1) return null;
  final size = _int(data[Schema.sizeBytes]);
  return AppRelease(
    id: id,
    versionName: versionName,
    versionCode: versionCode,
    releaseNotes: _text(data[Schema.releaseNotes], 4000),
    sizeBytes: size < 0 ? 0 : size,
    mandatory: data[Schema.mandatory] == true,
    createdAt: _date(data[Schema.createdAt]),
  );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

String versionLine(StoreApp app) {
  final size = formatBytes(app.sizeBytes);
  final suffix = size.isEmpty ? '' : ' · $size';
  return 'Version ${app.latestVersionName}$suffix';
}
