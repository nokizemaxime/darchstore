import '../../../core/error/catalog_exception.dart';
import '../domain/catalog_repository.dart';
import '../domain/models.dart';

class UnconfiguredCatalogRepository implements CatalogRepository {
  const UnconfiguredCatalogRepository();

  @override
  Future<CatalogBatch> fetchPublished({int limit = 40, String? startAfterId}) {
    throw CatalogException.notConfigured();
  }

  @override
  Future<StoreApp?> fetchById(String id) {
    throw CatalogException.notConfigured();
  }

  @override
  Future<List<AppRelease>> fetchReleases(String appId, {int limit = 15}) {
    throw CatalogException.notConfigured();
  }
}
