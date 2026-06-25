import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kesh_kart/OnBoarding/onboardingScreen.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/customer/home.dart';
import 'package:kesh_kart/login.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('seenOnboarding') ?? false;
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final role = prefs.getString('role');

      if (!hasSeenOnboarding) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OnboardingScreen()),
        );
        return;
      }

      if (isLoggedIn) {
        await NotificationService.requestPermissionAndSyncToken();
        if (role == 'customer') {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CustomerHome()),
          );
        } else if (role == 'barber') {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BarberHome()),
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
    });
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
