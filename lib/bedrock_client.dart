import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class BedrockClient {
  static const String baseUrl = 'https://api.keshkart.com';
  static const String projectKey = 'pk_dev_fbdd6a8f0dc9489c';
  static const Duration requestTimeout = Duration(seconds: 20);

  static final BedrockClient _instance = BedrockClient._internal();
  factory BedrockClient() => _instance;
  BedrockClient._internal();

  /// Exchanges a Firebase ID token for a Bedrock JWT session.
  Future<Map<String, dynamic>?> firebaseLogin(
    String idToken, {
    String deviceId = 'unknown',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/firebase-login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          'project_key': projectKey,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        final userId = data['user_id'];

        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('bedrock_token', accessToken.toString());
          if (userId != null) {
            await prefs.setString('bedrock_user_id', userId.toString());
          }
          return data;
        }
      } else {
        debugPrint(
          'Bedrock Login Failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Bedrock Login Error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> requestOtp(String phone) async {
    final response = await _publicRequest(
      'POST',
      'auth/otp/request',
      body: {'project_key': projectKey, 'phone': phone},
    );
    return response is Map<String, dynamic> ? response : null;
  }

  Future<Map<String, dynamic>?> verifyOtp(String phone, String otp) async {
    final response = await _publicRequest(
      'POST',
      'auth/otp/verify',
      body: {'project_key': projectKey, 'phone': phone, 'otp': otp},
    );

    if (response is Map<String, dynamic>) {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = response['access_token'];
      final refreshToken = response['refresh_token'];
      final userId = response['user_id'];
      if (accessToken != null) {
        await prefs.setString('bedrock_token', accessToken.toString());
      }
      if (refreshToken != null) {
        await prefs.setString('bedrock_refresh_token', refreshToken.toString());
      }
      if (userId != null) {
        await prefs.setString('bedrock_user_id', userId.toString());
      }
      return response;
    }

    return null;
  }

  /// Generic authenticated POST to create a document.
  Future<Map<String, dynamic>?> createDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    return await _authenticatedRequest(
          'POST',
          'collections/$collection',
          body: data,
        )
        as Map<String, dynamic>?;
  }

  /// Generic authenticated GET to fetch a single document.
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String documentId,
  ) async {
    return await _authenticatedRequest('GET', 'documents/$documentId')
        as Map<String, dynamic>?;
  }

  /// Generic authenticated PATCH to update a document.
  Future<Map<String, dynamic>?> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    return await _authenticatedRequest(
          'PATCH',
          'documents/$documentId',
          body: {
            'collection': collection,
            'project_id': projectKey,
            'patch': data,
          },
        )
        as Map<String, dynamic>?;
  }

  /// Generic authenticated GET to query a collection.
  Future<List<dynamic>> queryCollection(
    String collection, {
    Map<String, String>? params,
  }) async {
    final filters =
        (params ?? {}).entries
            .map((entry) => [entry.key, '==', entry.value])
            .toList();

    final response = await _authenticatedRequest(
      'POST',
      'query',
      body: {
        'collection': collection,
        'project_id': projectKey,
        'filters': filters,
        'limit': 100,
      },
    );

    if (response is Map<String, dynamic>) {
      final rows = response['results'] ?? response['data'] ?? [];
      if (rows is List) {
        return rows.map((row) {
          if (row is! Map<String, dynamic>) return row;
          final data = row['data'];
          if (data is Map<String, dynamic>) {
            return {...row, ...data, 'data': data, 'id': row['id']};
          }
          return row;
        }).toList();
      }
    }
    return [];
  }

  Future<String?> uploadFile(
    File file,
    String path, {
    String contentType = 'image/jpeg',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bedrock_token');

    if (token == null) {
      debugPrint('Bedrock Upload Error: No access token found.');
      return null;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/keshkart/upload/'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'X-Project-Key': projectKey,
      });
      request.fields['project_key'] = projectKey;
      request.fields['path'] = path;
      request.fields['content_type'] = contentType;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return data['download_url'] as String?;
      }

      debugPrint(
        'Bedrock Upload Failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      debugPrint('Bedrock Upload Error: $e');
    }

    return null;
  }

  Future<dynamic> _authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bedrock_token');

    if (token == null) {
      debugPrint('Bedrock Error: No access token found. Please login first.');
      return null;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Project-Key': projectKey,
    };

    final uri =
        path.contains('http')
            ? Uri.parse(path)
            : Uri.parse('$baseUrl/api/v1/$path/');

    try {
      final response = await _sendWithRetry(
        method,
        uri,
        headers: headers,
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        debugPrint(
          'Bedrock Request Failed ($method $path): ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Bedrock Request Error ($method $path): $e');
      return null;
    }
  }

  Future<dynamic> _publicRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/$path/');
    final headers = {'Content-Type': 'application/json'};

    try {
      final response = await _sendWithRetry(
        method,
        uri,
        headers: headers,
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      debugPrint(
        'Bedrock Public Request Failed ($method $path): ${response.statusCode} - ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Bedrock Public Request Error ($method $path): $e');
      return null;
    }
  }

  Future<http.Response> _sendWithRetry(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final encodedBody = body == null ? null : jsonEncode(body);
        switch (method) {
          case 'POST':
            return await http
                .post(uri, headers: headers, body: encodedBody)
                .timeout(requestTimeout);
          case 'PATCH':
            return await http
                .patch(uri, headers: headers, body: encodedBody)
                .timeout(requestTimeout);
          case 'GET':
          case 'GET_RAW':
            return await http
                .get(uri, headers: headers)
                .timeout(requestTimeout);
          default:
            throw Exception('Unsupported method: $method');
        }
      } catch (e) {
        lastError = e;
        if (attempt == 2) break;
        await Future.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }
    throw Exception(lastError ?? 'Request failed');
  }
}
