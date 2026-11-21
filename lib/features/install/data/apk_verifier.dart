import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../core/error/catalog_exception.dart';
import '../../../core/security/policies.dart';

Future<void> verifyDownloadedApk({
  required File file,
  required String expectedSha256,
  required int expectedSizeBytes,
}) async {
  if (!await file.exists()) {
    throw const DownloadRejected('Le fichier téléchargé est introuvable.');
  }
  final length = await file.length();
  if (length <= 0 || length > StoragePathPolicy.maxApkBytes) {
    throw const DownloadRejected('La taille du fichier est refusée.');
  }
  if (expectedSizeBytes > 0 && length != expectedSizeBytes) {
    throw const DownloadRejected(
      'La taille du fichier ne correspond pas au catalogue.',
    );
  }
  final header = await file
      .openRead(0, 4)
      .fold<List<int>>(<int>[], (previous, chunk) => previous..addAll(chunk));
  if (header.length < 2 || header[0] != 0x50 || header[1] != 0x4B) {
    throw const DownloadRejected(
      'Le fichier téléchargé n’est pas une archive APK.',
    );
  }
  final digest = await sha256.bind(file.openRead()).first;
  if (!secureEqualsHex(digest.toString(), expectedSha256)) {
    throw const DownloadRejected(
      'L’empreinte du fichier ne correspond pas au catalogue. Installation annulée.',
    );
  }
}

Future<void> deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
