import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dependencies.dart';
import '../../app/theme.dart';
import '../catalog/application/catalog_controller.dart';
import '../device/application/device_controller.dart';
import '../notifications/update_watcher.dart';

class StoreShell extends ConsumerStatefulWidget {
  const StoreShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends ConsumerState<StoreShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdates());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _onResume() async {
    await ref.read(catalogProvider.notifier).refresh();
    if (!mounted) return;
    ref.invalidate(installedAppsProvider);
    await _checkUpdates();
  }

  Future<void> _checkUpdates() async {
    if (!ref.read(notificationsEnabledProvider)) return;
    await ref.read(updateWatcherProvider).check();
  }

  @override
  Widget build(BuildContext context) {
    final updateCount = ref.watch(updateCountProvider);
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Catalogue',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: updateCount > 0,
              backgroundColor: AppColors.copper,
              textColor: AppColors.ink,
              label: Text(updateCount > 9 ? '9+' : '$updateCount'),
              child: const Icon(Icons.system_update_alt_rounded),
            ),
            label: 'Mises à jour',
          ),
          const NavigationDestination(
            icon: Icon(Icons.apps_rounded),
            label: 'Bibliothèque',
          ),
        ],
      ),
    );
  }
}
