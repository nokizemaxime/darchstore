import 'models.dart';

abstract class CatalogRepository {
  Future<CatalogBatch> fetchPublished({int limit = 40, String? startAfterId});

  Future<StoreApp?> fetchById(String id);

  Future<List<AppRelease>> fetchReleases(String appId, {int limit = 15});
}
