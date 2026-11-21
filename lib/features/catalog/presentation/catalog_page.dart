import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/error/catalog_exception.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/data/store_app_mapper.dart';
import '../../catalog/domain/catalog_logic.dart';
import '../../catalog/domain/models.dart';
import '../../device/application/device_controller.dart';
import '../../device/domain/installed_package.dart';
import '../../shell/store_widgets.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    return SafeArea(
      bottom: false,
      child: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CatalogError(error: error),
        data: (data) => _CatalogBody(data: data, search: _search),
      ),
    );
  }
}

class _CatalogError extends ConsumerWidget {
  const _CatalogError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = error;
    if (failure is CatalogException &&
        failure.kind == CatalogFailureKind.notConfigured) {
      return const _SetupView();
    }
    final message = failure is CatalogException
        ? failure.message
        : 'Le catalogue n’a pas pu être chargé.';
    return Center(
      child: StoreMessage(
        title: 'Catalogue indisponible',
        body: message,
        icon: Icons.cloud_off_rounded,
        actionLabel: 'Réessayer',
        onAction: () => ref.invalidate(catalogProvider),
      ),
    );
  }
}

class _CatalogBody extends ConsumerWidget {
  const _CatalogBody({required this.data, required this.search});

  final CatalogData data;
  final TextEditingController search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(catalogQueryProvider);
    final visible = ref.watch(visibleAppsProvider);
    final installed = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final categories = data.apps.map((app) => app.category).toSet().toList()
      ..sort();
    final showFeatured = query.text.trim().isEmpty && query.category == null;
    final featured = data.apps.where((app) => app.featured).take(8).toList();
    final mandatory = availableUpdates(
      data.apps,
      installed,
    ).where((app) => app.mandatory).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(catalogProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DARCH STORE',
                    style: TextStyle(
                      color: AppColors.copper,
                      fontSize: 12,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Catalogue',
                    style: TextStyle(
                      color: AppColors.parchment,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les applications publiées s’installent et se mettent à jour depuis ce téléphone, sans compte.',
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: search,
                    onChanged: (value) {
                      ref.read(catalogQueryProvider.notifier).setText(value);
                    },
                    style: const TextStyle(color: AppColors.parchment),
                    cursorColor: AppColors.copper,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une application',
                      hintStyle: const TextStyle(color: AppColors.muted),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.panel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('Toutes'),
                              selected: query.category == null,
                              showCheckmark: false,
                              onSelected: (_) {
                                ref
                                    .read(catalogQueryProvider.notifier)
                                    .selectCategory(null);
                              },
                            ),
                          ),
                          for (final category in categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(category),
                                selected: query.category == category,
                                showCheckmark: false,
                                onSelected: (_) {
                                  ref
                                      .read(catalogQueryProvider.notifier)
                                      .selectCategory(category);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (mandatory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MandatoryBanner(app: mandatory.first),
                  ],
                ],
              ),
            ),
          ),
          if (showFeatured && featured.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 168,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: featured.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _FeaturedCard(app: featured[index]);
                  },
                ),
              ),
            ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: StoreMessage(
                  title: data.apps.isEmpty
                      ? 'Aucune application'
                      : 'Aucun résultat',
                  body: data.apps.isEmpty
                      ? 'Les applications publiées apparaîtront ici.'
                      : 'Aucune application ne correspond à cette recherche.',
                  icon: Icons.search_off_rounded,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _AppTile(app: visible[index], installed: installed);
                },
              ),
            ),
          if (data.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: OutlinedButton(
                  onPressed: data.loadingMore
                      ? null
                      : () => ref.read(catalogProvider.notifier).loadMore(),
                  child: Text(
                    data.loadingMore ? 'Chargement…' : 'Charger plus',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MandatoryBanner extends StatelessWidget {
  const _MandatoryBanner({required this.app});

  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/apps/${app.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.priority_high_rounded, color: AppColors.copper),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mise à jour importante : ${app.name}',
                  style: const TextStyle(
                    color: AppColors.parchment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.app});

  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/apps/${app.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppMark(name: app.name, iconUrl: app.iconUrl, size: 48),
                const Spacer(),
                Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.parchment,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app.summary.isEmpty ? app.category : app.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.installed});

  final StoreApp app;
  final Map<String, InstalledPackage> installed;

  @override
  Widget build(BuildContext context) {
    final status = releaseStatus(app, installed[app.packageName]);
    return Material(
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/apps/${app.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AppMark(name: app.name, iconUrl: app.iconUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.parchment,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.developerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    if (app.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        app.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.parchment,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          versionLine(app),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        StatusPill(status: status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupView extends StatelessWidget {
  const _SetupView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: const [
        Text(
          'DARCH STORE',
          style: TextStyle(
            color: AppColors.copper,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Relier le catalogue',
          style: TextStyle(
            color: AppColors.parchment,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Le store est prêt. Il lui manque seulement le projet Firebase qui publiera les applications. Aucune connexion n’est demandée pour les consulter.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        SizedBox(height: 20),
        _Step(
          index: '1',
          text:
              'Créez un projet Firebase avec Firestore, Storage et l’authentification anonyme.',
        ),
        _Step(
          index: '2',
          text: 'À la racine du projet, exécutez flutterfire configure.',
        ),
        _Step(
          index: '3',
          text:
              'Déployez les règles : firebase deploy --only firestore,storage.',
        ),
        _Step(
          index: '4',
          text:
              'Déposez l’APK dans Storage, puis créez le document apps correspondant. Le contrat est décrit dans le README.',
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.panel,
            foregroundColor: AppColors.copper,
            child: Text(
              index,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.parchment, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
