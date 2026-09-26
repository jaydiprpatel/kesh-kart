import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:kesh_kart/access/public_legal_routes.dart';
import 'package:kesh_kart/access/web_startup_gate.dart';
import 'package:kesh_kart/app_navigation.dart';
import 'package:kesh_kart/firebase_options.dart';
import 'package:kesh_kart/layout/keshkart_desktop_frame.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:kesh_kart/splash.dart';
import 'package:kesh_kart/theme/keshkart_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  NotificationService.configureTapHandling();
  if (!kIsWeb) {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'KeshKart Barber',
      debugShowCheckedModeBanner: false,
      theme: KeshTheme.lightTheme,
      builder:
          (context, child) => KeshKartDesktopFrame(
            maxWidth: 1320,
            child: child ?? const SizedBox.shrink(),
          ),
      onGenerateInitialRoutes:
          (initialRoute) => publicInitialRoutes(
            initialRoute,
            kIsWeb ? const WebStartupGate() : const SplashScreen(),
          ),
      onGenerateRoute: publicLegalRoute,
    );
  }
}
