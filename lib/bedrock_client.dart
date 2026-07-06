import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class BedrockClient {
  static const String baseUrl = 'https://api.keshkart.com';
  static const String projectId = '1832d133-a293-44d1-ab05-4b843c84d0f3';
  static const String projectKey = 'pk_prod_keshkart_android';
  static const Duration requestTimeout = Duration(seconds: 20);

  static final BedrockClient _instance = BedrockClient._internal();
  factory BedrockClient() => _instance;
  BedrockClient._internal();

  Future<Map<String, dynamic>?> requestOtp(String phone) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/otp/request/');
    final response = await _sendWithRetry(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: {'project_key': projectKey, 'phone': phone},
    );
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        data['success'] = false;
        data['status_code'] = response.statusCode;
      }
      return data;
    }
    return null;
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

  Future<Map<String, dynamic>?> loginWithTruecaller({
    String? userType,
    String? accessToken,
    String? authorizationCode,
    String? codeVerifier,
  }) async {
    final body = <String, dynamic>{'project_key': projectKey};
    if (userType != null && userType.isNotEmpty) {
      body['user_type'] = userType;
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      body['access_token'] = accessToken;
    } else {
      body['authorization_code'] = authorizationCode;
      body['code_verifier'] = codeVerifier;
    }

    try {
      final response = await _sendWithRetry(
        'POST',
        Uri.parse('$baseUrl/api/v1/auth/truecaller/login/'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _storeAuthTokens(decoded);
      } else {
        decoded['success'] = false;
        decoded['status_code'] = response.statusCode;
      }
      return decoded;
    } catch (e) {
      debugPrint('Truecaller Login Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> _storeAuthTokens(Map<String, dynamic> response) async {
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
            'project_id': projectId,
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
        'project_id': projectId,
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
    return _uploadFileWithAuth(file, path, contentType: contentType);
  }

  Future<String?> _uploadFileWithAuth(
    File file,
    String path, {
    required String contentType,
    bool retried = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bedrock_token');
    final fileExists = await file.exists();
    final fileSize = fileExists ? await file.length() : -1;

    if (token == null) {
      debugPrint('Bedrock Upload Error: No access token found.');
      return null;
    }

    try {
      debugPrint(
        '[KeshKartUpload] start path=$path contentType=$contentType '
        'file=${file.path} exists=$fileExists bytes=$fileSize',
      );
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
      debugPrint(
        '[KeshKartUpload] response status=${response.statusCode} body=${response.body}',
      );

      if (response.statusCode == 401 && !retried) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _uploadFileWithAuth(
            file,
            path,
            contentType: contentType,
            retried: true,
          );
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final downloadUrl = data['download_url'] as String?;
        if (downloadUrl == null || downloadUrl.isEmpty) {
          debugPrint('Bedrock Upload Failed: response missing download_url');
          return null;
        }
        final isReadable = await _verifyDownloadUrl(downloadUrl);
        if (!isReadable) {
          debugPrint('Bedrock Upload Failed: uploaded file is not readable.');
          return null;
        }
        debugPrint(
          '[KeshKartUpload] success path=$path url=${_safeLogUrl(downloadUrl)}',
        );
        return downloadUrl;
      }

      debugPrint(
        'Bedrock Upload Failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      debugPrint('Bedrock Upload Error: $e');
    }

    return null;
  }

  Future<bool> _verifyDownloadUrl(String downloadUrl) async {
    try {
      final response = await http
          .get(Uri.parse(downloadUrl))
          .timeout(requestTimeout);
      debugPrint(
        '[KeshKartUpload] verify status=${response.statusCode} '
        'url=${_safeLogUrl(downloadUrl)} bytes=${response.bodyBytes.length}',
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint(
        'Bedrock Upload Verify Failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      debugPrint('Bedrock Upload Verify Error: $e');
    }
    return false;
  }

  Future<String?> getDownloadUrl(String pathOrUrl) async {
    return _getDownloadUrlWithAuth(pathOrUrl);
  }

  Future<String?> _getDownloadUrlWithAuth(
    String pathOrUrl, {
    bool retried = false,
  }) async {
    final storagePath = _storagePathFromUrl(pathOrUrl);
    if (storagePath == null || storagePath.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bedrock_token');

    if (token == null) {
      debugPrint('Bedrock Download URL Error: No access token found.');
      return null;
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/storage/download-url/',
    ).replace(queryParameters: {'project_id': projectId, 'path': storagePath});

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'X-Project-Key': projectKey,
            },
          )
          .timeout(requestTimeout);

      if (response.statusCode == 401 && !retried) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _getDownloadUrlWithAuth(pathOrUrl, retried: true);
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return data['download_url'] as String?;
      }

      debugPrint(
        'Bedrock Download URL Failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      debugPrint('Bedrock Download URL Error: $e');
    }

    return null;
  }

  Future<Map<String, dynamic>?> getShopVerification() async {
    return await _authenticatedRequest('GET', 'keshkart/shop-verification')
        as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> submitShopVerification({
    required String photoUrl,
    required String photoPath,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    return await _authenticatedRequest(
          'POST',
          'keshkart/shop-verification',
          body: {
            'project_key': projectKey,
            'photo_url': photoUrl,
            'photo_path': photoPath,
            'lat': latitude,
            'lng': longitude,
            'accuracy_meters': accuracyMeters,
            'captured_at': DateTime.now().toIso8601String(),
          },
        )
        as Map<String, dynamic>?;
  }

  Future<dynamic> _authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retried = false,
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
      } else if (response.statusCode == 401 && !retried) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _authenticatedRequest(method, path, body: body, retried: true);
        }
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

  Future<bool> _refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('bedrock_refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('Bedrock Token Refresh: no refresh token available.');
      return false;
    }

    try {
      final response = await _sendWithRetry(
        'POST',
        Uri.parse('$baseUrl/api/v1/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: {'refresh_token': refreshToken},
      );
      debugPrint('Bedrock Token Refresh: status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Bedrock Token Refresh Failed: ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body);
      final accessToken = data['access_token'];
      final newRefreshToken = data['refresh_token'];
      if (accessToken == null) return false;

      await prefs.setString('bedrock_token', accessToken.toString());
      if (newRefreshToken != null) {
        await prefs.setString(
          'bedrock_refresh_token',
          newRefreshToken.toString(),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Bedrock Token Refresh Error: $e');
      return false;
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

  String? _storagePathFromUrl(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.isEmpty || value.startsWith('shimmer_')) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return value;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('bucket');
    if (bucketIndex == -1 || segments.length <= bucketIndex + 2) {
      return null;
    }

    return segments.skip(bucketIndex + 2).join('/');
  }

  String _safeLogUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final expires = uri.queryParameters['expires'];
    final signature = uri.queryParameters['signature'];
    final safeQuery = <String, String>{};
    if (expires != null) safeQuery['expires'] = expires;
    if (signature != null) {
      safeQuery['signature'] =
          signature.length <= 8 ? signature : '${signature.substring(0, 8)}...';
    }
    return uri.replace(queryParameters: safeQuery).toString();
  }
}
