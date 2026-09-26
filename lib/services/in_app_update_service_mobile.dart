import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Checks Google Play for a newer KeshKart Barber build and launches Play's
/// immediate update flow when one is available. Local/debug installs are not
/// eligible for Play in-app updates, so their API errors are intentionally
/// ignored after being logged for diagnostics.
Future<void> checkForKeshKartAndroidUpdate() async {
  if (!Platform.isAndroid) return;

  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      await InAppUpdate.performImmediateUpdate();
    }
  } catch (error) {
    debugPrint('[KeshKartUpdate] Play update check skipped: $error');
  }
}
