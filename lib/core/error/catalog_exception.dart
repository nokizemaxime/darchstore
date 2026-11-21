enum CatalogFailureKind { notConfigured, offline, forbidden, unknown }

class CatalogException implements Exception {
  const CatalogException(this.kind, this.message);

  factory CatalogException.notConfigured() {
    return const CatalogException(
      CatalogFailureKind.notConfigured,
      'Firebase n’est pas configuré sur cette application.',
    );
  }

  factory CatalogException.offline() {
    return const CatalogException(
      CatalogFailureKind.offline,
      'Connexion impossible. Vérifiez le réseau, puis réessayez.',
    );
  }

  factory CatalogException.forbidden() {
    return const CatalogException(
      CatalogFailureKind.forbidden,
      'Le catalogue est protégé par les règles Firebase. Vérifiez qu’elles sont déployées.',
    );
  }

  factory CatalogException.unknown() {
    return const CatalogException(
      CatalogFailureKind.unknown,
      'Le catalogue n’a pas pu être chargé.',
    );
  }

  final CatalogFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

class DownloadRejected implements Exception {
  const DownloadRejected(this.message);

  final String message;

  @override
  String toString() => message;
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}
