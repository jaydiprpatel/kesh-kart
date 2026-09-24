import 'package:flutter/widgets.dart';
import 'package:kesh_kart/access/web_portal.dart';
import 'package:kesh_kart/barber/barber_portal_only_screen.dart';
import 'package:kesh_kart/barber/barber_mobile_only_screen.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/customer/home.dart';

/// The default browser build owns customer bookings. A barber web build must
/// opt in at compile time so it cannot accidentally expose the dashboard from
/// the public customer site.
class RoleLanding {
  static Widget customer() =>
      KeshKartWebPortal.isBarber
          ? const BarberPortalOnlyScreen()
          : const CustomerHome();

  static Widget barber() =>
      KeshKartWebPortal.isBarber
          ? const BarberHome()
          : const BarberMobileOnlyScreen();
}
