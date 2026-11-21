import '../../../core/security/policies.dart';
import '../../device/domain/installed_package.dart';
import 'models.dart';

enum UpdateDecision {
  install,
  update,
  upToDate,
  downgradeBlocked,
  signatureMismatch,
  incompatibleSdk,
}

abstract final class UpdatePolicy {
  static UpdateDecision decide({
    required int? installedVersionCode,
    required int remoteVersionCode,
    required String? installedCertSha256,
    required String remoteCertSha256,
    required int deviceSdk,
    required int minSdk,
  }) {
    if (minSdk > 0 && deviceSdk > 0 && deviceSdk < minSdk) {
      return UpdateDecision.incompatibleSdk;
    }
    if (installedVersionCode == null) return UpdateDecision.install;
    if (remoteVersionCode < installedVersionCode) {
      return UpdateDecision.downgradeBlocked;
    }
    if (remoteVersionCode == installedVersionCode) {
      return UpdateDecision.upToDate;
    }
    final installedCert = installedCertSha256;
    if (installedCert != null &&
        installedCert.isNotEmpty &&
        remoteCertSha256.isNotEmpty &&
        !secureEqualsHex(installedCert, remoteCertSha256)) {
      return UpdateDecision.signatureMismatch;
    }
    return UpdateDecision.update;
  }
}

extension UpdateDecisionMessage on UpdateDecision {
  String get blockedMessage {
    return switch (this) {
      UpdateDecision.downgradeBlocked =>
        'Une version plus récente est déjà installée. Le retour arrière est bloqué.',
      UpdateDecision.signatureMismatch =>
        'La signature publiée ne correspond pas à l’application installée. La mise à jour est bloquée pour conserver ses données.',
      UpdateDecision.incompatibleSdk =>
        'Cette version n’est pas compatible avec Android sur cet appareil.',
      UpdateDecision.install ||
      UpdateDecision.update ||
      UpdateDecision.upToDate => '',
    };
  }

  bool get isBlocked => blockedMessage.isNotEmpty;
}

enum ReleaseStatus { notInstalled, updateAvailable, upToDate, installedNewer }

ReleaseStatus releaseStatus(StoreApp app, InstalledPackage? installed) {
  if (installed == null) return ReleaseStatus.notInstalled;
  if (installed.versionCode < app.latestVersionCode) {
    return ReleaseStatus.updateAvailable;
  }
  if (installed.versionCode > app.latestVersionCode) {
    return ReleaseStatus.installedNewer;
  }
  return ReleaseStatus.upToDate;
}

String releaseStatusLabel(ReleaseStatus status) {
  return switch (status) {
    ReleaseStatus.notInstalled => 'Installer',
    ReleaseStatus.updateAvailable => 'Mise à jour',
    ReleaseStatus.upToDate => 'À jour',
    ReleaseStatus.installedNewer => 'Version locale plus récente',
  };
}

class CatalogQuery {
  const CatalogQuery({this.text = '', this.category});

  final String text;
  final String? category;

  CatalogQuery copyWith({
    String? text,
    String? category,
    bool clearCategory = false,
  }) {
    return CatalogQuery(
      text: text ?? this.text,
      category: clearCategory ? null : (category ?? this.category),
    );
  }
}

List<StoreApp> filterCatalog(List<StoreApp> apps, CatalogQuery query) {
  final text = query.text.trim().toLowerCase();
  final filtered = apps.where((app) {
    final categoryOk = query.category == null || app.category == query.category;
    if (!categoryOk) return false;
    if (text.isEmpty) return true;
    return app.name.toLowerCase().contains(text) ||
        app.summary.toLowerCase().contains(text) ||
        app.developerName.toLowerCase().contains(text) ||
        app.packageName.toLowerCase().contains(text) ||
        app.category.toLowerCase().contains(text);
  }).toList();
  filtered.sort((a, b) {
    if (a.featured != b.featured) return a.featured ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return filtered;
}

List<StoreApp> availableUpdates(
  List<StoreApp> apps,
  Map<String, InstalledPackage> installed,
) {
  final updates = apps.where((app) {
    return releaseStatus(app, installed[app.packageName]) ==
        ReleaseStatus.updateAvailable;
  }).toList();
  updates.sort((a, b) {
    if (a.mandatory != b.mandatory) return a.mandatory ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return updates;
}

List<StoreApp> installedCatalogApps(
  List<StoreApp> apps,
  Map<String, InstalledPackage> installed,
) {
  final list = apps
      .where((app) => installed.containsKey(app.packageName))
      .toList();
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}
