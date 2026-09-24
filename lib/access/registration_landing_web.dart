import 'package:flutter/widgets.dart';
import 'package:kesh_kart/access/web_portal.dart';
import 'package:kesh_kart/barber/barber_web_onboarding_screen.dart';
import 'package:kesh_kart/register.dart';

class RegistrationLanding {
  static Widget forRole({
    required String role,
    required String phoneNumber,
    required String userId,
  }) {
    if (KeshKartWebPortal.isBarber && role.trim().toLowerCase() == 'barber') {
      return BarberWebOnboardingScreen(
        phoneNumber: phoneNumber,
        userId: userId,
      );
    }
    return RegisterScreen(role: role, phoneNumber: phoneNumber, userId: userId);
  }
}
