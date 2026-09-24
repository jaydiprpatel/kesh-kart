import 'package:flutter/foundation.dart';

/// Identifies a deliberately scoped Flutter web build.
///
/// The standard KeshKart browser build remains customer-facing. The barber
/// portal is built explicitly with `--dart-define=KESHKART_WEB_PORTAL=barber`.
/// Mobile builds never opt into this mode.
class KeshKartWebPortal {
  static const String name = String.fromEnvironment(
    'KESHKART_WEB_PORTAL',
    defaultValue: 'customer',
  );

  static bool get isBarber => kIsWeb && name == 'barber';
}
