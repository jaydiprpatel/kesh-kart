import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kesh_kart/OnBoarding/onboardingScreen.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/customer/home.dart';
import 'package:kesh_kart/login.dart';
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
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Shimmer.fromColors(
              baseColor: Colors.grey[700]!,
              highlightColor: Colors.white,
              child: Image.asset(
                'assets/images/mustache.png',
                width: MediaQuery.of(context).size.width * 0.6,
              ),
            ),
            const Spacer(),
            Shimmer.fromColors(
              baseColor: Colors.grey[700]!,
              highlightColor: Colors.white,
              child: Text(
                'Kesh Kart',
                style: TextStyle(
                  fontFamily: 'Popins',
                  fontSize: 30,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
