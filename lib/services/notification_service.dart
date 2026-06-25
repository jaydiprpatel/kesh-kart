import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kesh_kart/app_navigation.dart';
import 'package:kesh_kart/barber/profile.dart';
import 'package:kesh_kart/barber/queue_management_screen.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/check_in_status_screen.dart';
import 'package:kesh_kart/customer/customer_bookings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _tapHandlingConfigured = false;

  static void configureTapHandling() {
    if (kIsWeb || _tapHandlingConfigured) return;
    _tapHandlingConfigured = true;

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openFromMessage(message);
    });

    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openFromMessage(message);
        });
      }
    });
  }

  static Future<void> requestPermissionAndSyncToken() async {
    if (kIsWeb) return;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '[KeshKartNotification] permission=${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await _messaging.getToken();
      final tokenPreview =
          token == null
              ? 'null'
              : '${token.substring(0, token.length > 12 ? 12 : token.length)}...';
      debugPrint('[KeshKartNotification] token=$tokenPreview');
      if (token == null || token.isEmpty) return;

      await _saveToken(token);
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[KeshKartNotification] token refreshed');
        await _saveToken(newToken);
      });
    } catch (error) {
      debugPrint('[KeshKartNotification] setup failed: $error');
    }
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final userId =
        prefs.getString('bedrock_user_id') ?? prefs.getString('userId');
    if (userId == null || userId.isEmpty) {
      await prefs.setString('pendingFcmToken', token);
      debugPrint('[KeshKartNotification] saved pending token');
      return;
    }

    await prefs.setString('fcmToken', token);
    final result = await BedrockClient().updateDocument('users', userId, {
      'fcmToken': token,
      'notificationProvider': 'fcm',
    });
    if (result == null) {
      await prefs.setString('pendingFcmToken', token);
      debugPrint('[KeshKartNotification] token sync failed');
    } else {
      await prefs.remove('pendingFcmToken');
      debugPrint('[KeshKartNotification] token synced userId=$userId');
    }
  }

  static Future<void> _openFromMessage(RemoteMessage message) async {
    final data = message.data;
    debugPrint('[KeshKartNotification] tap data=$data');
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final screen = (data['screen'] ?? '').toString();
    if (screen == 'customer_bookings' ||
        screen == 'appointment' ||
        screen == 'booking') {
      navigator.push(
        MaterialPageRoute(builder: (_) => const CustomerBookingsPage()),
      );
      return;
    }

    if (screen == 'check_in_status') {
      final shopId = (data['shopId'] ?? '').toString();
      if (shopId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => CheckInStatusScreen(shopId: shopId),
          ),
        );
        return;
      }
    }

    if (screen == 'barber_queue') {
      final prefs = await SharedPreferences.getInstance();
      final shopId =
          (data['shopId'] ??
                  prefs.getString('bedrock_user_id') ??
                  prefs.getString('userId') ??
                  '')
              .toString();
      if (shopId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => QueueManagementScreen(shopId: shopId),
          ),
        );
        return;
      }
    }

    if (screen == 'barber_profile') {
      final prefs = await SharedPreferences.getInstance();
      final barberId =
          (data['barberId'] ??
                  prefs.getString('bedrock_user_id') ??
                  prefs.getString('userId') ??
                  '')
              .toString();
      if (barberId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => BarberProfileScreen(barberId: barberId),
          ),
        );
      }
    }
  }
}
