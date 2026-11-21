import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/device/application/device_controller.dart';
import '../features/notifications/push_coordinator.dart';
import 'dependencies.dart';
import 'router.dart';
import 'theme.dart';

class DarchApp extends ConsumerWidget {
  const DarchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    if (ref.watch(firebaseReadyProvider)) {
      ref.watch(pushCoordinatorProvider);
      ref.watch(deviceSyncProvider);
    }
    return MaterialApp.router(
      title: 'Darch Store',
      theme: buildDarchTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
