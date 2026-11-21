import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/dependencies.dart';
import '../../core/firebase/schema.dart';
import '../catalog/application/catalog_controller.dart';
import '../catalog/domain/catalog_logic.dart';
import '../catalog/domain/models.dart';
import '../device/application/device_controller.dart';

final updateWatcherProvider = Provider<UpdateWatcher>(
  (ref) => UpdateWatcher(ref),
);

class UpdateWatcher {
  UpdateWatcher(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _running = false;

  Future<void> check() async {
    if (_running) return;
    if (!_ref.read(notificationsEnabledProvider)) return;
    if (!_ref.read(firebaseReadyProvider)) return;
    _running = true;
    try {
      final catalog = await _ref.read(catalogProvider.future);
      final installed = await _ref.read(installedAppsProvider.future);
      final updates = availableUpdates(catalog.apps, installed);
      if (updates.isEmpty) return;
      await _notify(updates);
    } catch (error, stack) {
      debugPrint('Vérification des mises à jour ignorée: $error\n$stack');
    } finally {
      _running = false;
    }
  }

  Future<void> _notify(List<StoreApp> updates) async {
    final fingerprint =
        (updates
                .map((app) => '${app.packageName}:${app.latestVersionCode}')
                .toList()
              ..sort())
            .join('|');
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getString('update_fingerprint');
    final notifiedAt = preferences.getInt('update_notified_at') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const cooldown = Duration(hours: 12);
    if (previous == fingerprint && now - notifiedAt < cooldown.inMilliseconds) {
      return;
    }
    await _ensureReady();
    final title = updates.length == 1
        ? 'Mise à jour : ${updates.first.name}'
        : '${updates.length} mises à jour disponibles';
    await _notifications.show(
      7041,
      title,
      'Ouvrez Darch Store pour les installer. Les données des applications sont conservées.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          Schema.notificationChannelId,
          'Mises à jour',
          channelDescription: 'Nouvelles versions publiées sur Darch Store',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
    await preferences.setString('update_fingerprint', fingerprint);
    await preferences.setInt('update_notified_at', now);
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: android),
    );
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        Schema.notificationChannelId,
        'Mises à jour',
        description: 'Nouvelles versions publiées sur Darch Store',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
    _ready = true;
  }
}
