import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/firebase/schema.dart';
import '../catalog/application/catalog_controller.dart';
import 'update_watcher.dart';

final pushCoordinatorProvider = NotifierProvider<PushCoordinator, void>(
  PushCoordinator.new,
);

class PushCoordinator extends Notifier<void> {
  @override
  void build() {
    final foreground = FirebaseMessaging.onMessage.listen((_) => _refresh());
    final opened = FirebaseMessaging.onMessageOpenedApp.listen((_) {
      ref.read(routerProvider).go('/updates');
      _refresh();
    });
    ref.onDispose(() {
      foreground.cancel();
      opened.cancel();
    });
    Future<void>(() async {
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: false,
          sound: true,
        );
        await FirebaseMessaging.instance.subscribeToTopic(Schema.updateTopic);
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) ref.read(routerProvider).go('/updates');
      } catch (error) {
        debugPrint('Notifications distantes indisponibles: $error');
      }
    });
  }

  Future<void> _refresh() async {
    await ref.read(catalogProvider.notifier).refresh();
    await ref.read(updateWatcherProvider).check();
  }
}
