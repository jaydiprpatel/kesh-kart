import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:kesh_kart/backend/baas_collection.dart';
import 'package:kesh_kart/backend/config.dart';
import 'package:kesh_kart/baas_options.dart';
import 'package:my_baas_sdk/my_baas_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class BaasClient {
  static final BaasClient instance = BaasClient._private();
  BaasClient._private();

  MyBaasClient? _sdk;
  MyBaasClient get sdk {
    if (_sdk == null) {
      throw Exception("BaasClient not initialized. Call init() first.");
    }
    return _sdk!;
  }

  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notifications =>
      _notificationController.stream;

  String? _signingSecret;

  Future<void> init() async {
    if (_sdk != null) return;

    _sdk = MyBaasClient.initialize(
      apiUrl: BaasConfig.restUrl,
      androidProjectKey: DefaultBaasOptions.androidKey,
      webProjectKey: DefaultBaasOptions.webKey,
      windowsProjectKey: DefaultBaasOptions.windowsKey,
      iosProjectKey: DefaultBaasOptions.iosKey,
      // Fallback for others if needed
      projectId: DefaultBaasOptions.androidKey,
      realtimeUrl: BaasConfig.wsUrl,
      tokenStorage: SecureTokenStorage(),
    );

    await _sdk!.ready;

    // One-time Migration from insecure SharedPreferences to SecureTokenStorage
    final prefs = await SharedPreferences.getInstance();
    final legacyAccess = prefs.getString('accessToken');
    final legacyRefresh = prefs.getString('refreshToken');
    if (legacyAccess != null) {
      debugPrint("🔐 Migrating legacy tokens to Secure Storage...");
      final secureStorage = SecureTokenStorage();
      await secureStorage.saveTokens(
        accessToken: legacyAccess,
        refreshToken: legacyRefresh ?? '',
      );
      // Clear legacy tokens
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      debugPrint("✅ Legacy tokens migrated and cleared.");
    }

    // _sdk!.realtime.onLog = (msg) => debugPrint("SDK LOG: $msg");

    _sdk!.realtime.events.listen((event) {
      debugPrint("SDK RAW WEBSOCKET EVENT: $event");

      if (event['type'] == 'notification') {
        final data = Map<String, dynamic>.from(event['data'] ?? {});
        debugPrint("SDK: Processing notification: ${data['title']}");

        // Milestone 3: Signed Payload Verification
        if (_verifySignature(data)) {
          debugPrint("SDK: Signature Valid. Adding to controller.");
          _notificationController.add(data);
          _updateLastNotifTime(data['updatedAt'] ?? data['createdAt']);
          _ackNotification(data['id']);
        } else {
          debugPrint("SDK: VERIFICATION FAILED. Notification dropped.");
        }
      } else if (event['type'] == 'notification_event' &&
          event['event'] == 'notification_updated') {
        debugPrint(
          "SDK: Received sync update for notification ${event['data']['id']}",
        );
        _notificationController.add({
          'type': 'updated',
          'id': event['data']['id'],
          'updates': event['data']['updates'],
        });
      }
    });

    await _sdk!.ready;

    // Always try to load session if existing
    await _sdk!.auth.loadSession();

    if (_sdk!.auth.currentUser != null) {
      await _fetchProjectConfig();
      _fetchMissedNotifications();
    }

    debugPrint("Baas SDK Initialized.");
  }

  /// Returns a collection reference.
  static dynamic collection(String path) {
    return BaasCollection(path);
  }

  Future<String> diagnoseConnection() async {
    if (BaasConfig.useFirebase) return "Firebase Mode";
    if (_sdk == null) return "SDK Not Initialized";
    return "SDK Initialized. REST: ${BaasConfig.restUrl}, WS: ${BaasConfig.wsUrl}. Connected: ${sdk.realtime.isConnected}";
  }

  /// Performs a semantic search using the AI client.
  Future<SemanticSearchResult> search({
    required String collection,
    required String query,
    int topK = 5,
  }) async {
    return await sdk.ai.vectorSearch(
      collection: collection,
      query: query,
      topK: topK,
    );
  }

  Future<Map<String, dynamic>> fetchInsights() async {
    try {
      final token = await SecureTokenStorage().getAccessToken();
      final response = await http.get(
        Uri.parse(
          '${BaasConfig.restUrl}/v1/projects/${DefaultBaasOptions.androidKey}/insights/',
        ),
        headers: {
          'X-Project-Key': DefaultBaasOptions.androidKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Fetch insights error: $e");
    }
    return {};
  }

  Future<void> updateFcmToken(String token) async {
    try {
      final user = sdk.auth.currentUser;
      if (user != null) {
        await collection('users').doc(user.id).update({'fcmToken': token});
        debugPrint("FCM Token updated for user ${user.id}");
      }
    } catch (e) {
      debugPrint("Error updating FCM Token: $e");
    }
  }

  Future<void> _updateLastNotifTime(String? timestamp) async {
    if (timestamp == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_notif_time', timestamp);
  }

  Future<void> _fetchMissedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final since = prefs.getString('last_notif_time');

      final token = await SecureTokenStorage().getAccessToken();
      final url = Uri.parse(
        '${BaasConfig.restUrl}/v1/notifications/inbox/',
      ).replace(queryParameters: since != null ? {'since': since} : {});

      final response = await http.get(
        url,
        headers: {
          'X-Project-Key': DefaultBaasOptions.androidKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'] ?? [];
        for (var notif in results) {
          final notifMap = Map<String, dynamic>.from(notif);
          _notificationController.add(notifMap);
          _updateLastNotifTime(notifMap['updatedAt'] ?? notifMap['createdAt']);
          _ackNotification(notifMap['id']); // Milestone 4: Acknowledgement
        }
      }
    } catch (e) {
      debugPrint("Fetch missed notifications error: $e");
    }
  }

  Future<void> _fetchProjectConfig() async {
    try {
      final token = await SecureTokenStorage().getAccessToken();
      final response = await http.get(
        Uri.parse('${BaasConfig.restUrl}/v1/auth/me/'),
        headers: {
          'X-Project-Key': DefaultBaasOptions.androidKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _signingSecret = data['signingSecret'];
        debugPrint(
          "Project Configuration loaded. Signing Secret: ${_signingSecret != null ? 'Present' : 'Missing'}",
        );
      }
    } catch (e) {
      debugPrint("Fetch project config error: $e");
    }
  }

  bool _verifySignature(Map<String, dynamic> data) {
    if (_signingSecret == null) {
      debugPrint("VERIFY: No secret loaded. Rejecting notification.");
      return false;
    }

    final metadata = Map<String, dynamic>.from(data['metadata'] ?? {});
    final signature = data['_signature'] ?? metadata['_signature'];

    final canonicalMetadata = Map<String, dynamic>.from(metadata);
    canonicalMetadata.remove('_signature');

    final title = data['title'] ?? '';
    final body = data['body'] ?? '';

    final keys = canonicalMetadata.keys.toList()..sort();
    final sortedMetadata = {for (var k in keys) k: canonicalMetadata[k]};

    // Use compact jsonEncode (no spaces)
    final metadataStr = json.encode(sortedMetadata);
    // Note: Dart's json.encode is compact by default (no spaces after : or ,)
    // which matches Python's separators=(',', ':')

    final payloadStr = "$title|$body|$metadataStr";

    final hmac = Hmac(sha256, utf8.encode(_signingSecret!));
    final digest = hmac.convert(utf8.encode(payloadStr));

    final calculated = digest.toString();

    if (signature == null) {
      debugPrint("VERIFY: No signature in payload. Rejecting.");
      return false;
    }

    final isValid = calculated == signature;
    if (!isValid) {
      debugPrint("VERIFY ERROR: HMAC mismatch.");
      debugPrint("SIGNATURE: $signature");
      debugPrint("CALCULATED: $calculated");
      debugPrint("PAYLOAD: '$payloadStr'");
      return false;
    }

    debugPrint("VERIFY SUCCESS: Signature valid for '$title'");
    return true;
  }

  Future<void> _ackNotification(String? id) async {
    if (id == null) return;
    try {
      final token = await SecureTokenStorage().getAccessToken();
      await http.post(
        Uri.parse('${BaasConfig.restUrl}/v1/notifications/ack/'),
        headers: {
          'X-Project-Key': DefaultBaasOptions.androidKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'notification_id': id}),
      );
      debugPrint("Notification $id acknowledged.");
    } catch (e) {
      debugPrint("Ack error: $e");
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final token = await SecureTokenStorage().getAccessToken();
      await http.post(
        Uri.parse('${BaasConfig.restUrl}/v1/notifications/mark-read/'),
        headers: {
          'X-Project-Key': DefaultBaasOptions.androidKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'notification_id': id}),
      );
      debugPrint("Notification $id marked as read.");
    } catch (e) {
      debugPrint("Mark read error: $e");
    }
  }
}

class SecureTokenStorage implements TokenStorage {
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'baas_access_token', value: accessToken);
    await _storage.write(key: 'baas_refresh_token', value: refreshToken);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'baas_access_token');
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'baas_refresh_token');
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: 'baas_access_token');
    await _storage.delete(key: 'baas_refresh_token');
  }
}

class Timestamp {
  final DateTime _dateTime;
  Timestamp(this._dateTime);
  DateTime toDate() => _dateTime;

  static Timestamp fromDateTime(DateTime dt) => Timestamp(dt);
  static Timestamp now() => Timestamp(DateTime.now());

  @override
  String toString() => _dateTime.toIso8601String();
}
