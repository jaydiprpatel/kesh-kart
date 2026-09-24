import 'package:flutter/widgets.dart';
import 'package:kesh_kart/access/web_booking_handoff_screen.dart';
import 'package:kesh_kart/barber/barber_registration_screen.dart';

class RegistrationLanding {
  static Widget forRole({
    required String role,
    required String phoneNumber,
    required String userId,
  }) {
    if (role.trim().toLowerCase() != 'barber') {
      return const WebBookingHandoffScreen();
    }
    return BarberRegistrationScreen(phoneNumber: phoneNumber, userId: userId);
  }
}
