abstract final class DocumentIdPolicy {
  static final RegExp pattern = RegExp(r'^[A-Za-z0-9_\-]{1,128}$');

  static bool allows(String value) => pattern.hasMatch(value);
}

abstract final class StoragePathPolicy {
  static final RegExp _pattern = RegExp(
    r'^releases/[A-Za-z0-9_\-]{1,128}/[A-Za-z0-9._\-]{1,128}\.apk$',
  );

  static const int maxApkBytes = 512 * 1024 * 1024;

  static bool allows(String path) => _pattern.hasMatch(path);
}

abstract final class PackageNamePolicy {
  static final RegExp pattern = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
  );

  static bool allows(String value) => pattern.hasMatch(value);
}

abstract final class DigestPolicy {
  static final RegExp sha256 = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp signature = RegExp(r'^[a-f0-9]{64}(,[a-f0-9]{64})*$');

  static bool isSha256(String value) => sha256.hasMatch(value);
  static bool isSignature(String value) => signature.hasMatch(value);
}

abstract final class HttpsUrlPolicy {
  static String? sanitize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return uri.toString();
  }
}

bool secureEqualsHex(String left, String right) {
  final a = left.trim().toLowerCase();
  final b = right.trim().toLowerCase();
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
