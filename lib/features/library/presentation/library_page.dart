import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/data/store_app_mapper.dart';
import '../../device/application/device_controller.dart';
import '../../shell/store_widgets.dart';

final storeVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return null;
  }
});

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final library = ref.watch(libraryAppsProvider);
    final version = ref.watch(storeVersionProvider).valueOrNull;
    return SafeArea(
      bottom: false,
      child: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: StoreMessage(
            title: 'Bibliothèque indisponible',
            body:
                'Le catalogue est nécessaire pour reconnaître les applications installées.',
            icon: Icons.cloud_off_rounded,
            actionLabel: 'Réessayer',
            onAction: () => ref.invalidate(catalogProvider),
          ),
        ),
        data: (data) {
          final installedState = ref.watch(installedAppsProvider);
          if (installedState.isLoading && !installedState.hasValue) {
            return const Center(child: CircularProgressIndicator());
          }
          if (installedState.hasError && !installedState.hasValue) {
            return const Center(
              child: StoreMessage(
                title: 'Téléphone illisible',
                body:
                    'Les applications déjà installées n’ont pas pu être lues.',
                icon: Icons.phonelink_erase_rounded,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              const Text(
                'Bibliothèque',
                style: TextStyle(
                  color: AppColors.parchment,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aucune connexion n’est demandée pour parcourir le store. Un identifiant anonyme sert seulement à compter les installations de cet appareil.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              if (library.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: StoreMessage(
                    title: 'Rien d’installé',
                    body:
                        'Les applications du catalogue apparaîtront ici une fois installées.',
                    icon: Icons.apps_rounded,
                  ),
                )
              else
                for (final app in library) ...[
                  Material(
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
                                    style: const TextStyle(
                                      color: AppColors.parchment,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    versionLine(app),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 12),
              Text(
                version == null ? 'Darch Store' : 'Darch Store $version',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}
