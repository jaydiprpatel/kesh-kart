import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kesh_kart/app_navigation.dart';
import 'package:kesh_kart/barber/profile.dart';
import 'package:kesh_kart/barber/queue_management_screen.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/customer_bookings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[KeshKartNotification] background message: id=${message.messageId} data=${message.data}',
  );
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String _webVapidKey = String.fromEnvironment(
    'KESH_KART_WEB_VAPID_KEY',
  );
  static const _androidChannel = AndroidNotificationChannel(
    'appointment_updates',
    'Appointment updates',
    description: 'Booking, queue, and appointment updates for your shop.',
    importance: Importance.high,
  );
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _tapHandlingConfigured = false;
  static bool _tokenRefreshConfigured = false;
  static Future<void>? _localNotificationsReady;

  static void configureTapHandling() {
    if (_tapHandlingConfigured) return;
    _tapHandlingConfigured = true;

    if (!kIsWeb) {
      _localNotificationsReady = _initializeLocalNotifications();
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[KeshKartNotification] foreground message: ${message.notification?.title} - ${message.notification?.body}',
      );
      unawaited(_showForegroundNotification(message));
    });

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

  static Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final rawPayload = response.payload;
        if (rawPayload == null || rawPayload.isEmpty) return;
        try {
          final decoded = jsonDecode(rawPayload);
          if (decoded is Map) {
            _openFromData(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // A malformed payload must not prevent the app from opening.
        }
      },
    );
    final android =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await android?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'KeshKart Notification';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';
    _showForegroundSnackBar(message, title, body);
    if (!kIsWeb) {
      await (_localNotificationsReady ??= _initializeLocalNotifications());
      await _localNotifications.show(
        (message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString())
            .hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  static void _showForegroundSnackBar(
    RemoteMessage message,
    String title,
    String body,
  ) {
    final context = appNavigatorKey.currentState?.context;
    if (context != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (body.isNotEmpty)
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.amberAccent,
            onPressed: () {
              _openFromMessage(message);
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<void> requestPermissionAndSyncToken() async {
    await enablePushAlerts();
  }

  /// Requests notification permission only after a customer explicitly opts in.
  ///
  /// Web FCM tokens require the public VAPID key supplied during the web build.
  static Future<PushAlertSetupResult> enablePushAlerts() async {
    if (kIsWeb && _webVapidKey.trim().isEmpty) {
      debugPrint('[KeshKartNotification] web VAPID key is not configured');
      return PushAlertSetupResult.vapidKeyMissing;
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '[KeshKartNotification] permission=${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return PushAlertSetupResult.permissionDenied;
      }

      final token =
          kIsWeb
              ? await _messaging.getToken(vapidKey: _webVapidKey)
              : await _messaging.getToken();
      final tokenPreview =
          token == null
              ? 'null'
              : '${token.substring(0, token.length > 12 ? 12 : token.length)}...';
      debugPrint('[KeshKartNotification] token=$tokenPreview');
      if (token == null || token.isEmpty) {
        return PushAlertSetupResult.tokenUnavailable;
      }

      await _saveToken(token);
      if (!_tokenRefreshConfigured) {
        _tokenRefreshConfigured = true;
        _messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('[KeshKartNotification] token refreshed');
          await _saveToken(newToken);
        });
      }
      return PushAlertSetupResult.enabled;
    } catch (error) {
      debugPrint('[KeshKartNotification] setup failed: $error');
      return PushAlertSetupResult.failed;
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
    await _openFromData(message.data);
  }

  static Future<void> _openFromData(Map<String, dynamic> data) async {
    debugPrint('[KeshKartNotification] tap data=$data');
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final screen = (data['screen'] ?? '').toString();

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

    if (screen == 'customer_bookings') {
      navigator.push(
        MaterialPageRoute(builder: (_) => const CustomerBookingsPage()),
      );
    }
  }
}

enum PushAlertSetupResult {
  enabled,
  permissionDenied,
  vapidKeyMissing,
  tokenUnavailable,
  failed,
}
