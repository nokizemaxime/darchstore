import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/schema.dart';
import '../../../core/security/policies.dart';
import '../catalog/domain/models.dart';

enum StatsType { view, download, install, update }

class StatsRepository {
  StatsRepository({required this.isReady});

  final bool Function() isReady;
  final Set<String> _views = <String>{};

  Future<void> recordView(StoreApp app) {
    if (!_views.add(app.id)) return Future<void>.value();
    return _write(
      appId: app.id,
      packageName: app.packageName,
      type: StatsType.view,
      versionCode: app.latestVersionCode,
    );
  }

  Future<void> record({
    required String appId,
    required String packageName,
    required StatsType type,
    required int versionCode,
  }) {
    return _write(
      appId: appId,
      packageName: packageName,
      type: type,
      versionCode: versionCode,
    );
  }

  Future<void> _write({
    required String appId,
    required String packageName,
    required StatsType type,
    required int versionCode,
  }) async {
    if (!isReady()) return;
    if (!DocumentIdPolicy.allows(appId) ||
        !PackageNamePolicy.allows(packageName) ||
        versionCode < 1) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection(Schema.statsEvents).add({
        Schema.appId: appId,
        Schema.packageName: packageName,
        Schema.type: type.name,
        Schema.versionCode: versionCode,
        Schema.deviceId: uid,
        Schema.createdAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Statistique non enregistrée: $error');
    }
  }
}
