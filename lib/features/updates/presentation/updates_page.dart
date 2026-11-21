import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/error/catalog_exception.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../device/application/device_controller.dart';
import '../../shell/store_widgets.dart';

class UpdatesPage extends ConsumerWidget {
  const UpdatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final updates = ref.watch(updatesProvider);
    return SafeArea(
      bottom: false,
      child: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final message = error is CatalogException
              ? error.message
              : 'Les mises à jour n’ont pas pu être vérifiées.';
          return Center(
            child: StoreMessage(
              title: 'Vérification impossible',
              body: message,
              icon: Icons.cloud_off_rounded,
              actionLabel: 'Réessayer',
              onAction: () => ref.invalidate(catalogProvider),
            ),
          );
        },
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
          if (updates.isEmpty) {
            return const Center(
              child: StoreMessage(
                title: 'Aucune mise à jour',
                body:
                    'Les applications installées depuis le catalogue sont à jour.',
                icon: Icons.verified_rounded,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            itemCount: updates.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _UpdatesHeader();
              }
              final app = updates[index - 1];
              final installed = ref
                  .watch(installedAppsProvider)
                  .valueOrNull?[app.packageName];
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
                                style: const TextStyle(
                                  color: AppColors.parchment,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                installed == null
                                    ? app.latestVersionName
                                    : '${installed.versionName} → ${app.latestVersionName}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              if (app.mandatory)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Obligatoire',
                                    style: TextStyle(
                                      color: AppColors.copper,
                                      fontWeight: FontWeight.w700,
                                    ),
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
              );
            },
          );
        },
      ),
    );
  }
}

class _UpdatesHeader extends StatelessWidget {
  const _UpdatesHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mises à jour',
            style: TextStyle(
              color: AppColors.parchment,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Une mise à jour remplace l’application et conserve ses données lorsque le certificat reste le même.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
