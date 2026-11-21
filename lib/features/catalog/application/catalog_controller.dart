import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/error/catalog_exception.dart';
import '../domain/catalog_logic.dart';
import '../domain/models.dart';

class CatalogData {
  const CatalogData({
    required this.apps,
    required this.hasMore,
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<StoreApp> apps;
  final bool hasMore;
  final String? nextCursor;
  final bool loadingMore;

  CatalogData copyWith({
    List<StoreApp>? apps,
    bool? hasMore,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) {
    return CatalogData(
      apps: apps ?? this.apps,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class CatalogNotifier extends AsyncNotifier<CatalogData> {
  bool _refreshing = false;

  @override
  Future<CatalogData> build() => _load(null);

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final previous = state.valueOrNull;
    try {
      state = AsyncData(await _load(null));
    } catch (error, stack) {
      debugPrint('Actualisation du catalogue: $error\n$stack');
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stack);
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        _refreshing) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _load(current.nextCursor);
      final merged = [...current.apps];
      for (final app in page.apps) {
        if (merged.every((item) => item.id != app.id)) merged.add(app);
      }
      state = AsyncData(page.copyWith(apps: merged, loadingMore: false));
    } catch (error, stack) {
      debugPrint('Page suivante: $error\n$stack');
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<CatalogData> _load(String? cursor) async {
    try {
      final page = await ref
          .read(catalogRepositoryProvider)
          .fetchPublished(startAfterId: cursor);
      return CatalogData(
        apps: page.apps,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } on CatalogException {
      rethrow;
    } catch (error, stack) {
      debugPrint('Catalogue: $error\n$stack');
      throw CatalogException.unknown();
    }
  }
}

final catalogProvider = AsyncNotifierProvider<CatalogNotifier, CatalogData>(
  CatalogNotifier.new,
);

class CatalogQueryController extends Notifier<CatalogQuery> {
  @override
  CatalogQuery build() => const CatalogQuery();

  void setText(String value) {
    state = state.copyWith(text: value);
  }

  void selectCategory(String? category) {
    if (category == null || category == state.category) {
      state = state.copyWith(clearCategory: true);
      return;
    }
    state = state.copyWith(category: category);
  }
}

final catalogQueryProvider =
    NotifierProvider<CatalogQueryController, CatalogQuery>(
      CatalogQueryController.new,
    );

final visibleAppsProvider = Provider<List<StoreApp>>((ref) {
  final data = ref.watch(catalogProvider).valueOrNull;
  if (data == null) return const [];
  return filterCatalog(data.apps, ref.watch(catalogQueryProvider));
});

final appDetailsProvider = FutureProvider.family<StoreApp?, String>((
  ref,
  id,
) async {
  final cached = ref
      .watch(catalogProvider)
      .valueOrNull
      ?.apps
      .where((app) => app.id == id)
      .firstOrNull;
  if (cached != null) return cached;
  return ref.watch(catalogRepositoryProvider).fetchById(id);
});

final releasesProvider = FutureProvider.family<List<AppRelease>, String>((
  ref,
  id,
) {
  return ref.watch(catalogRepositoryProvider).fetchReleases(id);
});
