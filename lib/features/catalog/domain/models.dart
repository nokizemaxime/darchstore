import 'package:equatable/equatable.dart';

class StoreApp extends Equatable {
  const StoreApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.summary,
    required this.description,
    required this.category,
    required this.developerName,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.releaseNotes,
    required this.apkStoragePath,
    required this.sha256,
    required this.signatureSha256,
    required this.sizeBytes,
    required this.minSdk,
    required this.mandatory,
    required this.featured,
    required this.downloadCount,
    required this.updatedAt,
    this.iconUrl,
    this.websiteUrl,
  });

  final String id;
  final String name;
  final String packageName;
  final String summary;
  final String description;
  final String category;
  final String developerName;
  final String latestVersionName;
  final int latestVersionCode;
  final String releaseNotes;
  final String apkStoragePath;
  final String sha256;
  final String signatureSha256;
  final int sizeBytes;
  final int minSdk;
  final bool mandatory;
  final bool featured;
  final int downloadCount;
  final DateTime updatedAt;
  final String? iconUrl;
  final String? websiteUrl;

  @override
  List<Object?> get props => [
    id,
    name,
    packageName,
    summary,
    description,
    category,
    developerName,
    latestVersionName,
    latestVersionCode,
    releaseNotes,
    apkStoragePath,
    sha256,
    signatureSha256,
    sizeBytes,
    minSdk,
    mandatory,
    featured,
    downloadCount,
    updatedAt,
    iconUrl,
    websiteUrl,
  ];
}

class AppRelease extends Equatable {
  const AppRelease({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.releaseNotes,
    required this.sizeBytes,
    required this.mandatory,
    required this.createdAt,
  });

  final String id;
  final String versionName;
  final int versionCode;
  final String releaseNotes;
  final int sizeBytes;
  final bool mandatory;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    versionName,
    versionCode,
    releaseNotes,
    sizeBytes,
    mandatory,
    createdAt,
  ];
}

class CatalogBatch {
  const CatalogBatch({
    required this.apps,
    required this.hasMore,
    this.nextCursor,
  });

  final List<StoreApp> apps;
  final bool hasMore;
  final String? nextCursor;
}
