import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../bedrock_client.dart';

class CheckInResponse {
  final bool success;
  final int position;
  final int estimatedWaitTime;
  final bool locationUnverified;
  final String? errorMessage;

  CheckInResponse({
    required this.success,
    this.position = 0,
    this.estimatedWaitTime = 0,
    this.locationUnverified = false,
    this.errorMessage,
  });
}

class CheckInService {
  static final Set<String> _inFlightCheckIns = {};

  static Future<CheckInResponse> checkIn({
    required String shopId,
    required String appointmentId,
  }) async {
    final requestKey = '$shopId:$appointmentId';
    if (_inFlightCheckIns.contains(requestKey)) {
      return CheckInResponse(
        success: false,
        errorMessage: 'Check-in is already in progress.',
      );
    }

    _inFlightCheckIns.add(requestKey);
    try {
      // 1. Try to get Location
      double? lat;
      double? lng;
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          try {
            Position position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 5),
              ),
            );
            lat = position.latitude;
            lng = position.longitude;
          } catch (e) {
            // Location fetch failed
          }
        }
      }

      // 2. Call Bedrock Backend API
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bedrock_token');

      if (token == null) {
        return CheckInResponse(
          success: false,
          errorMessage: 'Not logged in to Bedrock.',
        );
      }

      final url = Uri.parse(
        '${BedrockClient.baseUrl}/api/v1/keshkart/check-in/',
      );
      final response = await _postWithRetry(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: {
          'shopId': shopId,
          'appointmentId': appointmentId,
          'lat': lat,
          'lng': lng,
          'project_key': BedrockClient.projectKey,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return CheckInResponse(
          success: data['success'] ?? false,
          position: data['position'] ?? 0,
          estimatedWaitTime: data['estimatedWaitTime'] ?? 0,
          locationUnverified: data['locationUnverified'] ?? false,
          errorMessage: data['alreadyCheckedIn'] == true ? null : data['error'],
        );
      } else {
        return CheckInResponse(
          success: false,
          errorMessage:
              data['error'] ??
              'Check-in failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      return CheckInResponse(success: false, errorMessage: e.toString());
    } finally {
      _inFlightCheckIns.remove(requestKey);
    }
  }

  static Future<http.Response> _postWithRetry(
    Uri url, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http
            .post(url, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode < 500 || attempt == 2) {
          return response;
        }
      } catch (e) {
        lastError = e;
        if (attempt == 2) break;
      }
      await Future.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }
    throw Exception(lastError ?? 'Check-in request failed');
  }
}
