import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/darch_app.dart';
import 'app/dependencies.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF10141A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final ready = await bootstrapFirebase();
  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(ready)],
      child: const DarchApp(),
    ),
  );
}
