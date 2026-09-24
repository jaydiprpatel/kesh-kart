import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kesh_kart/access/role_landing.dart';
import 'package:kesh_kart/access/web_portal.dart';
import 'package:kesh_kart/barber/barber_web_landing_screen.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves a stored browser session without showing the mobile splash screen.
class WebStartupGate extends StatefulWidget {
  const WebStartupGate({super.key});

  @override
  State<WebStartupGate> createState() => _WebStartupGateState();
}

class _WebStartupGateState extends State<WebStartupGate> {
  Widget _page =
      KeshKartWebPortal.isBarber
          ? const BarberWebLandingScreen()
          : const LogInScreen();

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('isLoggedIn') != true) return;

    final role = preferences.getString('role');
    if (role == 'barber' || role == 'customer') {
      unawaited(
        BedrockClient.instance.recordAppOpen(
          appVersion: '1.0.0',
          platform: 'web',
        ),
      );
    }
    if (!mounted) return;

    setState(() {
      _page =
          role == 'barber'
              ? RoleLanding.barber()
              : role == 'customer'
              ? RoleLanding.customer()
              : const LogInScreen();
    });
  }

  @override
  Widget build(BuildContext context) => _page;
}
