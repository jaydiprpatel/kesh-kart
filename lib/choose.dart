import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kesh_kart/access/registration_landing.dart';
import 'package:kesh_kart/access/web_portal.dart';

/// Directs an authenticated person whose profile is not yet complete to the
/// only onboarding flow available in the running KeshKart surface.
///
/// The Android application is barber-only. The ordinary browser portal is
/// customer-only, while the separately built barber portal is barber-only.
/// A person should never need to choose a role after verifying their phone.
class Choose extends StatelessWidget {
  const Choose({super.key, required this.phoneNumber, required this.userId});

  final String phoneNumber;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final isBarberFlow = !kIsWeb || KeshKartWebPortal.isBarber;
    return RegistrationLanding.forRole(
      userId: userId,
      phoneNumber: phoneNumber,
      role: isBarberFlow ? 'Barber' : 'Customer',
    );
  }
}
