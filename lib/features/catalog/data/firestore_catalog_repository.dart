import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/error/catalog_exception.dart';
import '../../../core/firebase/schema.dart';
import '../../../core/security/policies.dart';
import '../domain/catalog_repository.dart';
import '../domain/models.dart';
import 'store_app_mapper.dart';

class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _apps =>
      _firestore.collection(Schema.apps);

  @override
  Future<CatalogBatch> fetchPublished({
    int limit = 40,
    String? startAfterId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _apps
          .where(Schema.published, isEqualTo: true)
          .orderBy(Schema.updatedAt, descending: true)
          .limit(limit);
      if (startAfterId != null && DocumentIdPolicy.allows(startAfterId)) {
        final cursor = await _apps.doc(startAfterId).get();
        if (cursor.exists) query = query.startAfterDocument(cursor);
      }
      final snap = await query.get();
      final apps = <StoreApp>[];
      for (final doc in snap.docs) {
        final app = mapStoreApp(doc.id, doc.data());
        if (app != null) apps.add(app);
      }
      return CatalogBatch(
        apps: apps,
        hasMore: snap.docs.length == limit,
        nextCursor: snap.docs.isEmpty ? null : snap.docs.last.id,
      );
    } on FirebaseException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<StoreApp?> fetchById(String id) async {
    if (!DocumentIdPolicy.allows(id)) return null;
    try {
      final doc = await _apps.doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return mapStoreApp(doc.id, data);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return null;
      throw _failure(error);
    }
  }

  @override
  Future<List<AppRelease>> fetchReleases(String appId, {int limit = 15}) async {
    if (!DocumentIdPolicy.allows(appId)) return const [];
    try {
      final snap = await _apps
          .doc(appId)
          .collection(Schema.versions)
          .where(Schema.published, isEqualTo: true)
          .orderBy(Schema.versionCode, descending: true)
          .limit(limit)
          .get();
      return [
        for (final doc in snap.docs)
          if (mapRelease(doc.id, doc.data()) case final release?) release,
      ];
    } on FirebaseException catch (error) {
      debugPrint('Historique indisponible: ${error.code}');
      throw _failure(error);
    }
  }

  CatalogException _failure(FirebaseException error) {
    debugPrint('Catalogue Firebase: ${error.code}');
    return switch (error.code) {
      'unavailable' ||
      'network-request-failed' ||
      'deadline-exceeded' => CatalogException.offline(),
      'permission-denied' || 'unauthenticated' => CatalogException.forbidden(),
      _ => CatalogException.unknown(),
    };
  }
}
