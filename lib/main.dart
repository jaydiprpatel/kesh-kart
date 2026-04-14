import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:kesh_kart/splash.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/barber/appointment_history.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:kesh_kart/providers/booking_provider.dart';
import 'package:kesh_kart/providers/auth_provider.dart';
import 'package:kesh_kart/providers/payment_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final Set<String> _processedNotificationIds = {};

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> initNotifications() async {
  if (kIsWeb) return;

  // Request notification permission for Android 13+
  await Permission.notification.request();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_notification');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint("APP: Local Notification Clicked: ${response.payload}");
      if (response.payload != null) {
        try {
          final data = json.decode(response.payload!) as Map<String, dynamic>;
          handleNotificationClick(data);
        } catch (e) {
          debugPrint("APP: Error parsing notification payload: $e");
        }
      }
    },
  );

  // Explicitly create the channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'appointment_updates',
    'Appointment Updates',
    description: 'Notifications for appointment status updates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

Future<String> _downloadAndSaveFile(String url, String fileName) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  final String filePath = '${directory.path}/$fileName';
  final http.Response response = await http.get(Uri.parse(url));
  final File file = File(filePath);
  await file.writeAsBytes(response.bodyBytes);
  return filePath;
}

Future<void> showLocalNotification(Map<String, dynamic> notif) async {
  if (kIsWeb) return;

  final String? id =
      notif['id']?.toString() ??
      notif['messageId']?.toString() ??
      notif['metadata']?['id']?.toString();

  debugPrint(
    "APP: showLocalNotification for ID: $id (Title: ${notif['title']})",
  );

  if (id != null) {
    if (_processedNotificationIds.contains(id)) {
      debugPrint("APP: DEDUPLICATED - ID $id already processed.");
      return;
    }
    _processedNotificationIds.add(id);
  }

  String? imageUrl = notif['image'] ?? notif['imageUrl'];
  if (imageUrl == null && notif['metadata'] != null) {
    imageUrl = notif['metadata']['imageUrl'] ?? notif['metadata']['image'];
  }

  BigPictureStyleInformation? bigPictureStyleInformation;
  if (imageUrl != null && imageUrl.isNotEmpty) {
    try {
      final String bigPicturePath = await _downloadAndSaveFile(
        imageUrl,
        'notification_img',
      );
      bigPictureStyleInformation = BigPictureStyleInformation(
        FilePathAndroidBitmap(bigPicturePath),
        largeIcon: FilePathAndroidBitmap(bigPicturePath),
        contentTitle: notif['title'],
        summaryText: notif['body'],
      );
    } catch (e) {
      debugPrint("Error downloading notification image: $e");
    }
  }

  String? category =
      notif['category'] ?? notif['metadata']?['category']?.toString();
  // Default category if none provided to ensure grouping works for appointments
  category ??= 'appointment_updates';
  String groupKey = 'com.keshkart.notifications.$category';

  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'appointment_updates',
        'Appointment Updates',
        channelDescription: 'Updates about your salon appointments',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        color: const Color(0xFF00D189),
        styleInformation: bigPictureStyleInformation,
        groupKey: groupKey,
      );

  NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  int notificationId =
      id != null ? id.hashCode : DateTime.now().millisecondsSinceEpoch % 100000;

  await flutterLocalNotificationsPlugin.show(
    notificationId,
    notif['title'] ?? 'Notification',
    notif['body'] ?? '',
    platformChannelSpecifics,
  );

  // Show/Update Group Summary for Android
  await flutterLocalNotificationsPlugin.show(
    category.hashCode, // Consistent ID for this category's summary
    '${category.toUpperCase()} Updates',
    'You have multiple notifications.',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'appointment_updates',
        'Appointment Updates',
        groupKey: groupKey,
        setAsGroupSummary: true,
        importance: Importance.max,
        priority: Priority.high,
        color: const Color(0xFF00D189),
      ),
    ),
    payload: json.encode(notif['metadata'] ?? {}),
  );
}

void handleNotificationClick(Map<String, dynamic> metadata) async {
  debugPrint(
    "APP: Handling Notification Click (Action) with metadata: $metadata",
  );

  final String category = metadata['category']?.toString() ?? '';

  // Navigation Logic
  if (category == 'appointment_updates' ||
      category == 'reschedule' ||
      category == 'reminder') {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final userId = prefs.getString('userId');

    if (role == 'barber' && userId != null) {
      debugPrint("APP: Navigating to AppointmentHistoryScreen for Barber");
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AppointmentHistoryScreen(barberId: userId),
        ),
      );
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  await initNotifications();

  try {
    await BaasClient.instance.init().timeout(const Duration(seconds: 30));
    debugPrint(await BaasClient.instance.diagnoseConnection());
  } catch (e) {
    debugPrint("BaasClient Init Failed or Timed Out: $e");
  }

  await Future.delayed(const Duration(milliseconds: 500));

  BaasClient.instance.notifications.listen((notif) {
    debugPrint("APP: Notification Listener triggered for: ${notif['title']}");
    // 1. Show System Notification (Real)
    if (!kIsWeb) {
      showLocalNotification(notif);
    }

    // 2. Show In-App Snackbar (Visual Feedback)
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notif['title'] ?? 'Notification',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(notif['body'] ?? ''),
          ],
        ),
        backgroundColor: const Color(0xFF00D189),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 5),
      ),
    );
  });

  if (!kIsWeb) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM Foreground Message: ${message.notification?.title}");
      if (message.notification != null) {
        showLocalNotification({
          'id':
              message.data['id'] ??
              message.messageId, // Use Synced Id if available
          'title': message.notification!.title,
          'body': message.notification!.body,
          'image': message.notification!.android?.imageUrl,
          'metadata': message.data,
        });
      }
    });

    // Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("APP: FCM Message Opened App: ${message.messageId}");
      handleNotificationClick(message.data);
    });

    // Handle initial message when app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint("APP: FCM Initial Message: ${message.messageId}");
        handleNotificationClick(message.data);
      }
    });

    // Ensure BaasClient is initialized before trying to update token
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint("FCM DEVICE TOKEN: $token");
      if (token != null) {
        debugPrint("APP: Attempting to update FCM token on BaaS...");
        await BaasClient.instance.updateFcmToken(token);
        debugPrint("APP: FCM Token update call finished (check BaaS logs)");
      } else {
        debugPrint("APP: FCM Token is NULL - cannot update BaaS");
      }
    } catch (e) {
      debugPrint("APP: Error fetching or updating FCM token: $e");
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // final bool debugDisableShaderWarmUp = true;
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D189),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}
