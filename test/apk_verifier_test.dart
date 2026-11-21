import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:darchstore/core/error/catalog_exception.dart';
import 'package:darchstore/features/install/data/apk_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepte un fichier dont l’empreinte correspond', () async {
    final file = await _apk(<int>[0x50, 0x4B, 3, 4, 9, 8, 7]);
    addTearDown(() => file.parent.delete(recursive: true));
    final bytes = await file.readAsBytes();
    await verifyDownloadedApk(
      file: file,
      expectedSha256: sha256.convert(bytes).toString(),
      expectedSizeBytes: bytes.length,
    );
  });

  test('refuse une empreinte différente', () async {
    final file = await _apk(<int>[0x50, 0x4B, 1, 2, 3]);
    addTearDown(() => file.parent.delete(recursive: true));
    expect(
      () => verifyDownloadedApk(
        file: file,
        expectedSha256: 'a' * 64,
        expectedSizeBytes: 0,
      ),
      throwsA(isA<DownloadRejected>()),
    );
  });

  test('refuse un fichier qui n’est pas une archive', () async {
    final file = await _apk(<int>[1, 2, 3, 4]);
    addTearDown(() => file.parent.delete(recursive: true));
    final bytes = await file.readAsBytes();
    expect(
      () => verifyDownloadedApk(
        file: file,
        expectedSha256: sha256.convert(bytes).toString(),
        expectedSizeBytes: bytes.length,
      ),
      throwsA(isA<DownloadRejected>()),
    );
  });
}

Future<File> _apk(List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp('darchstore-test');
  final file = File('${directory.path}/app.apk');
  await file.writeAsBytes(bytes);
  return file;
}
