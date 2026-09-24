import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kesh_kart/access/role_landing.dart';
import 'package:kesh_kart/OnBoarding/onboardingScreen.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/login.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;
  static const _barberAudienceNoticeSeenKey = 'barberAppAudienceNoticeSeenV1';

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(seconds: 3), _routeFromSplash);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  Future<void> _routeFromSplash() async {
    final prefs = await SharedPreferences.getInstance();
    if (!kIsWeb && !(prefs.getBool(_barberAudienceNoticeSeenKey) ?? false)) {
      if (!mounted) return;
      final visitCustomerWebsite = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => PopScope(
              canPop: false,
              child: AlertDialog(
                title: const Text('KeshKart Barber'),
                content: const Text(
                  'This mobile app is for barbers and salon owners. Customers can browse and book at keshkart.com.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Visit keshkart.com'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Continue as barber'),
                  ),
                ],
              ),
            ),
      );

      await prefs.setBool(_barberAudienceNoticeSeenKey, true);
      if (visitCustomerWebsite == true) {
        await launchUrl(
          Uri.parse('https://keshkart.com'),
          mode: LaunchMode.externalApplication,
        );
      }
      if (!mounted) return;
    }

    final hasSeenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final role = prefs.getString('role');

    if (!hasSeenOnboarding && !kIsWeb) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnboardingScreen()),
      );
      return;
    }

    if (isLoggedIn) {
      unawaited(
        BedrockClient.instance.recordAppOpen(
          appVersion: '1.0.0',
          platform: 'flutter',
        ),
      );
      if (!kIsWeb && role == 'barber') {
        await NotificationService.requestPermissionAndSyncToken();
      }
      if (role == 'customer') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RoleLanding.customer()),
        );
      } else if (role == 'barber') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RoleLanding.barber()),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LogInScreen()),
        );
      }
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LogInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Shimmer.fromColors(
              baseColor: const Color(0xFF54647A),
              highlightColor: const Color(0xFF091426),
              child: Image.asset(
                'assets/images/mustache.png',
                width: MediaQuery.of(context).size.width * 0.6,
                color: const Color(0xFF091426),
              ),
            ),
            const Spacer(),
            Shimmer.fromColors(
              baseColor: const Color(0xFF54647A),
              highlightColor: const Color(0xFF091426),
              child: const Text(
                'Kesh Kart',
                style: TextStyle(
                  fontFamily: 'Popins',
                  fontSize: 30,
                  color: Color(0xFF091426),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
