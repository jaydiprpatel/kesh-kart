import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kesh_kart/app_navigation.dart';
import 'package:kesh_kart/firebase_options.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:kesh_kart/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  NotificationService.configureTapHandling();
  await Future.delayed(const Duration(milliseconds: 500));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'KeshKart',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF091426),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF1E293B),
          onPrimaryContainer: Color(0xFF8590A6),
          secondary: Color(0xFF505F76),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFD0E1FB),
          onSecondaryContainer: Color(0xFF54647A),
          surface: Color(0xFFF8F9FA),
          onSurface: Color(0xFF191C1D),
          surfaceContainerHighest: Color(0xFFE1E3E4),
          onSurfaceVariant: Color(0xFF45474C),
          outline: Color(0xFF75777D),
          outlineVariant: Color(0xFFC5C6CD),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
    );
  }
}
