import 'package:flutter/widgets.dart';
import 'package:kesh_kart/access/web_booking_handoff_screen.dart';
import 'package:kesh_kart/barber/home.dart';

/// Mobile builds bind only barber feature routes.
class RoleLanding {
  static Widget customer() => const WebBookingHandoffScreen();

  static Widget barber() => const BarberHome();
}
