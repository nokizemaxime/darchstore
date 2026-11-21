import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/error/catalog_exception.dart';
import '../../../core/security/policies.dart';
import 'apk_verifier.dart';

abstract class ApkDownloader {
  Future<File> download({
    required String storagePath,
    required String packageName,
    required int versionCode,
    required int expectedSizeBytes,
    required void Function(double? progress) onProgress,
  });

  Future<void> cancelActive();
}

class UnavailableApkDownloader implements ApkDownloader {
  const UnavailableApkDownloader();

  @override
  Future<void> cancelActive() async {}

  @override
  Future<File> download({
    required String storagePath,
    required String packageName,
    required int versionCode,
    required int expectedSizeBytes,
    required void Function(double? progress) onProgress,
  }) {
    throw const DownloadRejected('Firebase n’est pas configuré.');
  }
}

class StorageApkDownloader implements ApkDownloader {
  StorageApkDownloader(this._storage);

  final FirebaseStorage _storage;
  DownloadTask? _active;

  @override
  Future<void> cancelActive() async {
    await _active?.cancel();
  }

  @override
  Future<File> download({
    required String storagePath,
    required String packageName,
    required int versionCode,
    required int expectedSizeBytes,
    required void Function(double? progress) onProgress,
  }) async {
    if (!StoragePathPolicy.allows(storagePath)) {
      throw const DownloadRejected('Chemin de fichier refusé.');
    }
    if (expectedSizeBytes > StoragePathPolicy.maxApkBytes) {
      throw const DownloadRejected('Ce fichier dépasse la taille autorisée.');
    }
    if (_active != null) {
      throw const DownloadRejected('Un téléchargement est déjà en cours.');
    }
    if (!PackageNamePolicy.allows(packageName) || versionCode < 1) {
      throw const DownloadRejected(
        'Cette version ne peut pas être téléchargée.',
      );
    }

    final directory = Directory('${(await getTemporaryDirectory()).path}/apk');
    await directory.create(recursive: true);
    final safeName = packageName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/$safeName-$versionCode.apk');
    if (await file.exists()) await file.delete();

    final reference = _storage.ref(storagePath);
    final task = reference.writeToFile(file);
    _active = task;
    var tooLarge = false;
    var succeeded = false;
    final subscription = task.snapshotEvents.listen(
      (snapshot) {
        final total = snapshot.totalBytes;
        if (total > StoragePathPolicy.maxApkBytes) {
          tooLarge = true;
          task.cancel();
          return;
        }
        if (total > 0) {
          onProgress(snapshot.bytesTransferred / total);
        } else {
          onProgress(null);
        }
      },
      onError: (Object error) {
        debugPrint('Progression ignorée: $error');
      },
    );

    try {
      await task.timeout(const Duration(minutes: 15));
      if (tooLarge) {
        throw const DownloadRejected('Ce fichier dépasse la taille autorisée.');
      }
      succeeded = true;
      return file;
    } on TimeoutException {
      await task.cancel();
      throw const DownloadRejected('Le téléchargement a expiré.');
    } on DownloadRejected {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint('Téléchargement refusé: ${error.code}');
      if (tooLarge) {
        throw const DownloadRejected('Ce fichier dépasse la taille autorisée.');
      }
      if (error.code == 'canceled') throw const DownloadCancelled();
      if (error.code == 'object-not-found') {
        throw const DownloadRejected(
          'Le fichier de cette version est introuvable.',
        );
      }
      if (error.code == 'unauthorized' || error.code == 'permission-denied') {
        throw const DownloadRejected(
          'Le téléchargement est refusé par les règles Storage.',
        );
      }
      throw const DownloadRejected('Le fichier n’a pas pu être téléchargé.');
    } finally {
      await subscription.cancel();
      if (identical(_active, task)) _active = null;
      if (!succeeded) await deleteQuietly(file);
    }
  }
}
