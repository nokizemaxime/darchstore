import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme.dart';
import '../../../core/format/formatters.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/data/store_app_mapper.dart';
import '../../catalog/domain/catalog_logic.dart';
import '../../catalog/domain/models.dart';
import '../../device/application/device_controller.dart';
import '../../device/domain/installed_package.dart';
import '../../install/application/install_controller.dart';
import '../../install/domain/install_state.dart';
import '../../shell/store_widgets.dart';

class DetailsPage extends ConsumerStatefulWidget {
  const DetailsPage({required this.appId, super.key});

  final String appId;

  @override
  ConsumerState<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends ConsumerState<DetailsPage> {
  var _tracked = false;

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(appDetailsProvider(widget.appId));
    final app = details.valueOrNull;
    if (app != null && !_tracked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tracked) return;
        _tracked = true;
        ref.read(statsRepositoryProvider).recordView(app);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: StoreMessage(
            title: 'Fiche indisponible',
            body: 'Cette application n’a pas pu être chargée.',
            icon: Icons.cloud_off_rounded,
            actionLabel: 'Retour',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
        data: (loaded) {
          if (loaded == null) {
            return Center(
              child: StoreMessage(
                title: 'Introuvable',
                body: 'Cette application n’est pas publiée.',
                icon: Icons.hide_source_rounded,
                actionLabel: 'Retour',
                onAction: () => Navigator.of(context).maybePop(),
              ),
            );
          }
          return _DetailsBody(app: loaded);
        },
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({required this.app});

  final StoreApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref
        .watch(installedAppsProvider)
        .valueOrNull?[app.packageName];
    final installState = ref.watch(installControllerProvider(app.id));
    final releases = ref.watch(releasesProvider(app.id));
    final status = releaseStatus(app, installed);
    final onAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.ink,
          title: Text(app.name),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppMark(name: app.name, iconUrl: app.iconUrl, size: 84),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: const TextStyle(
                              color: AppColors.parchment,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${app.developerName} · ${app.category}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 10),
                          StatusPill(status: status),
                        ],
                      ),
                    ),
                  ],
                ),
                if (app.summary.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    app.summary,
                    style: const TextStyle(
                      color: AppColors.parchment,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
                if (app.mandatory &&
                    status == ReleaseStatus.updateAvailable) ...[
                  const SizedBox(height: 16),
                  const _Note(
                    icon: Icons.priority_high_rounded,
                    text: 'Cette mise à jour est marquée comme obligatoire.',
                  ),
                ],
                const SizedBox(height: 18),
                _InstallPanel(
                  app: app,
                  installed: installed,
                  state: installState,
                  onAndroid: onAndroid,
                ),
                const SizedBox(height: 28),
                const _SectionTitle('À propos'),
                const SizedBox(height: 8),
                Text(
                  app.description.isEmpty
                      ? 'Aucune description.'
                      : app.description,
                  style: const TextStyle(
                    color: AppColors.parchment,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionTitle('Version'),
                const SizedBox(height: 8),
                Text(
                  '${versionLine(app)} · ${androidGeneration(app.minSdk)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (installed != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Installée : ${installed.versionName} (${installed.versionCode})',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
                if (app.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    app.releaseNotes,
                    style: const TextStyle(
                      color: AppColors.parchment,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const _SectionTitle('Historique'),
                const SizedBox(height: 8),
                releases.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => const Text(
                    'L’historique n’est pas disponible.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Text(
                        'Seule la dernière version publiée peut être installée.',
                        style: TextStyle(color: AppColors.muted),
                      );
                    }
                    return Column(
                      children: [
                        for (final release in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              release.versionName,
                              style: const TextStyle(
                                color: AppColors.parchment,
                              ),
                            ),
                            subtitle: Text(
                              [
                                formatDate(release.createdAt),
                                if (release.releaseNotes.isNotEmpty)
                                  release.releaseNotes,
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                const _SectionTitle('Sécurité'),
                const SizedBox(height: 8),
                SelectableText(
                  'SHA-256  ${app.sha256}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (app.signatureSha256.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    'Certificat  ${shortDigest(app.signatureSha256)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Le fichier est vérifié avant l’installation. Une mise à jour avec le même certificat conserve les données de l’application. Une signature différente est refusée.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                if (app.websiteUrl != null) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => _openWebsite(app.websiteUrl!),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Site de l’application'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openWebsite(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _InstallPanel extends ConsumerWidget {
  const _InstallPanel({
    required this.app,
    required this.installed,
    required this.state,
    required this.onAndroid,
  });

  final StoreApp app;
  final InstalledPackage? installed;
  final InstallState state;
  final bool onAndroid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = state;
    final status = releaseStatus(app, installed);
    final label = switch (phase) {
      InstallNeedsPermission() => 'Autoriser l’installation',
      InstallDownloading() => 'Téléchargement…',
      InstallVerifying() => 'Vérification…',
      InstallAwaitingUser() => 'Confirmation Android',
      InstallSuccess() => 'Ouvrir',
      _ when !onAndroid => 'Disponible sur Android',
      _
          when status == ReleaseStatus.upToDate ||
              status == ReleaseStatus.installedNewer =>
        'Ouvrir',
      _ when status == ReleaseStatus.updateAvailable => 'Mettre à jour',
      _ => 'Installer',
    };
    final busy = phase.isBusy;
    final canOpen =
        phase is InstallSuccess ||
        (phase is InstallIdle &&
            (status == ReleaseStatus.upToDate ||
                status == ReleaseStatus.installedNewer));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phase is InstallDownloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(value: phase.progress),
          ),
        if (phase is InstallFailure)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              phase.message,
              style: const TextStyle(color: AppColors.danger, height: 1.35),
            ),
          ),
        if (phase is InstallAwaitingUser)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Confirmez l’installation dans l’écran Android. Les données existantes sont conservées.',
              style: TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ),
        FilledButton(
          onPressed: !onAndroid || busy
              ? null
              : () => _onPressed(context, ref, canOpen: canOpen),
          child: Text(label),
        ),
        if (phase is InstallDownloading) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                ref.read(installControllerProvider(app.id).notifier).cancel(),
            child: const Text('Annuler'),
          ),
        ],
      ],
    );
  }

  Future<void> _onPressed(
    BuildContext context,
    WidgetRef ref, {
    required bool canOpen,
  }) async {
    if (!onAndroid) return;
    final phase = state;
    if (phase is InstallNeedsPermission) {
      final opened = await ref
          .read(packageBridgeProvider)
          .openInstallPermissionSettings();
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ouvrez les réglages et autorisez cette source.'),
          ),
        );
      }
      return;
    }
    if (canOpen) {
      final opened = await ref
          .read(packageBridgeProvider)
          .openApp(app.packageName);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('L’application ne peut pas être ouverte.'),
          ),
        );
      }
      return;
    }
    await ref.read(installControllerProvider(app.id).notifier).install(app);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.parchment,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.copper, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.parchment)),
        ),
      ],
    );
  }
}
