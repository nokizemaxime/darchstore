import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await bootstrapFirebase(attachMessaging: false, signIn: false);
}

Future<bool> bootstrapFirebase({
  bool attachMessaging = true,
  bool signIn = true,
}) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      debugPrint('Firebase indisponible: ${error.code}');
      return false;
    }
  } catch (error) {
    debugPrint('Firebase non configuré: $error');
    return false;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (error) {
    debugPrint('App Check non activé: $error');
  }

  if (attachMessaging) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (error) {
      debugPrint('Messages distants déjà enregistrés: $error');
    }
  }

  if (signIn) {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (error) {
      debugPrint('Authentification anonyme indisponible: $error');
    }
  }
  return true;
}
