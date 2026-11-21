import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/firebase/schema.dart';
import '../../../core/security/policies.dart';
import '../domain/installed_package.dart';

class DeviceRepository {
  DeviceRepository({required this.isReady});

  final bool Function() isReady;

  Future<void> sync(Map<String, InstalledPackage> installed) async {
    if (!isReady()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final apps = <String, Map<String, Object>>{};
    for (final entry in installed.entries) {
      if (apps.length >= 100) break;
      if (!PackageNamePolicy.allows(entry.key)) continue;
      final versionName = entry.value.versionName.trim();
      final signature = entry.value.signatureSha256.trim().toLowerCase();
      apps[entry.key] = {
        Schema.versionCode: entry.value.versionCode,
        Schema.versionName: versionName.length <= 40
            ? versionName
            : versionName.substring(0, 40),
        Schema.signatureSha256: signature.length <= 200
            ? signature
            : signature.substring(0, 200),
      };
    }
    try {
      final info = await _storeVersion();
      await FirebaseFirestore.instance.collection(Schema.devices).doc(uid).set({
        Schema.deviceId: uid,
        Schema.storeVersion: info,
        Schema.updatedAt: FieldValue.serverTimestamp(),
        Schema.appsMap: apps,
      });
    } catch (error) {
      debugPrint('Appareil non synchronisé: $error');
    }
  }

  Future<String> _storeVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = '${info.version}+${info.buildNumber}';
      return version.length <= 32 ? version : version.substring(0, 32);
    } catch (_) {
      return '0';
    }
  }
}
