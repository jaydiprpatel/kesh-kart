import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Service to handle Next-Gen Silent Phone Verification.
/// This service orchestrates Handshake -> Attestation -> Silent SMS intercept -> Completion.
class SilentAuthException implements Exception {
  final String message;
  final bool needsManualOtp;
  final String? nonce;

  SilentAuthException(this.message, {this.needsManualOtp = false, this.nonce});

  @override
  String toString() => "SilentAuthException: $message";
}

class SilentAuthService {
  static final SilentAuthService instance = SilentAuthService._private();
  SilentAuthService._private();

  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  /// Main entry point for the silent flow.
  /// Returns [Map<String, dynamic>] on success (user tokens), or null/throws on failure/fallback.
  Future<Map<String, dynamic>?> verifyPhoneNumberSilent(String phone) async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint(
        "Silent Verification is only supported on Android native devices.",
      );
      return null;
    }

    final Completer<Map<String, dynamic>?> completer = Completer();

    debugPrint("[FIREBASE SILENT] Starting native verification for $phone");

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 30),
      verificationCompleted: (fb.PhoneAuthCredential credential) async {
        debugPrint("[FIREBASE SILENT] Frictionless success! Verified via SIM.");
        try {
          final userCredential = await _firebaseAuth.signInWithCredential(
            credential,
          );
          final idToken = await userCredential.user?.getIdToken();

          if (idToken != null) {
            final deviceId = await _getDeviceId();
            final result = await BaasClient.instance.sdk.auth
                .signInWithFirebase(idToken: idToken, deviceId: deviceId);
            completer.complete(result);
          } else {
            completer.completeError(
              SilentAuthException("Failed to get Firebase ID Token"),
            );
          }
        } catch (e) {
          completer.completeError(
            SilentAuthException("Frictionless Login Failed: $e"),
          );
        }
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        debugPrint("[FIREBASE SILENT] Verification failed: ${e.message}");
        if (!completer.isCompleted) {
          completer.completeError(
            SilentAuthException("Firebase Error: ${e.message}"),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        debugPrint(
          "[FIREBASE SILENT] Code sent to $phone. Manual entry required.",
        );
        if (!completer.isCompleted) {
          completer.completeError(
            SilentAuthException(
              "Redirecting to manual OTP",
              needsManualOtp: true,
              nonce: verificationId,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint("[FIREBASE SILENT] Retrieval timeout for $verificationId");
      },
    );

    return completer.future;
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('installation_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('installation_id', id);
    }
    return id;
  }
}
