import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/presentation/catalog_page.dart';
import '../features/details/presentation/details_page.dart';
import '../features/library/presentation/library_page.dart';
import '../features/shell/store_shell.dart';
import '../features/updates/presentation/updates_page.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) => createRouter());

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/catalog',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return StoreShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/catalog',
                builder: (context, state) => const CatalogPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/updates',
                builder: (context, state) => const UpdatesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/apps/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id.isEmpty) return const _MissingPage();
          return DetailsPage(appId: id);
        },
      ),
    ],
    errorBuilder: (context, state) => const _MissingPage(),
  );
}

class _MissingPage extends StatelessWidget {
  const _MissingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Text(
          'Cette page n’existe pas.',
          style: TextStyle(color: AppColors.parchment),
        ),
      ),
    );
  }
}
