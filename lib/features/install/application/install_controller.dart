import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/error/catalog_exception.dart';
import '../../../core/security/policies.dart';
import '../../catalog/domain/catalog_logic.dart';
import '../../catalog/domain/models.dart';
import '../../device/application/device_controller.dart';
import '../../device/domain/installed_package.dart';
import '../../stats/stats_repository.dart';
import '../data/apk_verifier.dart';
import '../domain/install_state.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(isReady: () => ref.read(firebaseReadyProvider));
});

final installControllerProvider =
    NotifierProvider.family<InstallController, InstallState, String>(
      InstallController.new,
    );

class InstallController extends FamilyNotifier<InstallState, String> {
  String? _awaitingPackage;
  bool _updating = false;
  bool _cancelRequested = false;
  int? _versionCode;
  String? _packageName;

  @override
  InstallState build(String arg) {
    final bridge = ref.watch(packageBridgeProvider);
    final subscription = bridge.events.listen(
      _onEvent,
      onError: (Object error, StackTrace stack) {
        debugPrint('Flux d’installation: $error\n$stack');
      },
    );
    ref.onDispose(subscription.cancel);
    return const InstallIdle();
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    _awaitingPackage = null;
    await ref.read(apkDownloaderProvider).cancelActive();
    state = const InstallIdle();
  }

  Future<void> install(StoreApp app) async {
    if (state.isBusy) return;
    _cancelRequested = false;
    _packageName = app.packageName;
    _versionCode = app.latestVersionCode;
    final bridge = ref.read(packageBridgeProvider);

    if (!await bridge.canRequestInstalls()) {
      state = const InstallNeedsPermission();
      return;
    }

    final installed = await bridge.getInstalled([app.packageName]);
    final current = installed[app.packageName];
    final decision = UpdatePolicy.decide(
      installedVersionCode: current?.versionCode,
      remoteVersionCode: app.latestVersionCode,
      installedCertSha256: current?.signatureSha256,
      remoteCertSha256: app.signatureSha256,
      deviceSdk: await bridge.deviceSdk(),
      minSdk: app.minSdk,
    );
    if (decision == UpdateDecision.upToDate) {
      state = const InstallIdle();
      return;
    }
    if (decision.isBlocked) {
      state = InstallFailure(decision.blockedMessage);
      return;
    }

    _updating = current != null;
    state = const InstallDownloading(0);
    File? downloaded;
    try {
      final file = await ref
          .read(apkDownloaderProvider)
          .download(
            storagePath: app.apkStoragePath,
            packageName: app.packageName,
            versionCode: app.latestVersionCode,
            expectedSizeBytes: app.sizeBytes,
            onProgress: (progress) {
              if (!_cancelRequested) state = InstallDownloading(progress);
            },
          );
      downloaded = file;
      if (_cancelRequested) return;
      state = const InstallVerifying();
      await verifyDownloadedApk(
        file: file,
        expectedSha256: app.sha256,
        expectedSizeBytes: app.sizeBytes,
      );
      final archiveSignature = await bridge.readArchiveSignature(file.path);
      _ensureCertificate(app, current, archiveSignature);
      await ref
          .read(statsRepositoryProvider)
          .record(
            appId: app.id,
            packageName: app.packageName,
            type: StatsType.download,
            versionCode: app.latestVersionCode,
          );
      _awaitingPackage = app.packageName;
      state = const InstallAwaitingUser();
      await bridge.installApk(
        path: file.path,
        packageName: app.packageName,
        versionCode: app.latestVersionCode,
      );
    } on DownloadCancelled {
      state = _cancelRequested
          ? const InstallIdle()
          : const InstallFailure('Téléchargement interrompu.');
    } on DownloadRejected catch (error) {
      state = InstallFailure(error.message);
    } on PlatformException catch (error) {
      if (error.code == 'PERMISSION') {
        state = const InstallNeedsPermission();
      } else {
        state = InstallFailure(
          error.message ?? 'Impossible de lancer l’installation.',
        );
      }
    } catch (error, stack) {
      debugPrint('Installation: $error\n$stack');
      state = const InstallFailure('Le téléchargement a échoué.');
    } finally {
      final file = downloaded;
      if (file != null) await deleteQuietly(file);
    }
  }

  void _ensureCertificate(
    StoreApp app,
    InstalledPackage? current,
    String? archiveSignature,
  ) {
    final archive = archiveSignature?.trim().toLowerCase() ?? '';
    if (current != null) {
      if (archive.isEmpty) {
        throw const DownloadRejected(
          'Impossible de lire le certificat de cette mise à jour.',
        );
      }
      if (current.signatureSha256.isNotEmpty &&
          !secureEqualsHex(current.signatureSha256, archive)) {
        throw const DownloadRejected(
          'Le certificat est différent de l’application déjà installée. Mise à jour bloquée pour conserver ses données.',
        );
      }
    }
    if (app.signatureSha256.isNotEmpty &&
        (archive.isEmpty || !secureEqualsHex(app.signatureSha256, archive))) {
      throw const DownloadRejected(
        'Le certificat de l’APK ne correspond pas à celui qui a été publié.',
      );
    }
  }

  void _onEvent(InstallEvent event) {
    if (_awaitingPackage == null || event.packageName != _awaitingPackage) {
      return;
    }
    switch (event.status) {
      case InstallEventStatus.awaitingUser:
        state = const InstallAwaitingUser();
      case InstallEventStatus.success:
        _awaitingPackage = null;
        state = const InstallSuccess();
        ref.invalidate(installedAppsProvider);
        final packageName = _packageName;
        final versionCode = _versionCode;
        if (packageName != null && versionCode != null) {
          ref
              .read(statsRepositoryProvider)
              .record(
                appId: arg,
                packageName: packageName,
                type: _updating ? StatsType.update : StatsType.install,
                versionCode: versionCode,
              );
        }
      case InstallEventStatus.cancelled:
        _awaitingPackage = null;
        state = const InstallFailure('Installation annulée.');
      case InstallEventStatus.failure:
        _awaitingPackage = null;
        state = InstallFailure(event.message ?? 'L’installation a échoué.');
    }
  }
}
