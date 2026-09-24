import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class BedrockClient {
  // Override only in an isolated staging build. Production defaults remain
  // unchanged, so Cashfree sandbox activity cannot reach the live API.
  static const String baseUrl = String.fromEnvironment(
    'KESHKART_API_BASE_URL',
    defaultValue: 'https://api.keshkart.com',
  );
  static const String projectId = String.fromEnvironment(
    'KESHKART_PROJECT_ID',
    defaultValue: '1832d133-a293-44d1-ab05-4b843c84d0f3',
  );
  static const String projectKey = String.fromEnvironment(
    'KESHKART_PROJECT_KEY',
    defaultValue: 'pk_prod_keshkart_android',
  );
  static const Duration requestTimeout = Duration(seconds: 20);

  static final BedrockClient _instance = BedrockClient._internal();
  static final Random _mutationRandom = Random.secure();
  factory BedrockClient() => _instance;
  static BedrockClient get instance => _instance;
  BedrockClient._internal();

  /// The Bedrock idempotency store uses a UUID primary key. Keep the generated
  /// value stable for retries of the same request, but never use timestamp
  /// strings because they cannot be persisted by that UUID field.
  static String _newMutationId() {
    final bytes = List<int>.generate(
      16,
      (_) => _mutationRandom.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // UUID v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

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

  /// Restricted to the single server-configured Razorpay reviewer account.
  /// Normal KeshKart accounts continue to use OTP sign-in.
  Future<Map<String, dynamic>?> loginAsRazorpayReviewer({
    required String phone,
    required String password,
  }) async {
    final response = await _publicRequest(
      'POST',
      'auth/reviewer/login',
      body: {'project_key': projectKey, 'phone': phone, 'password': password},
    );
    if (response is Map<String, dynamic>) {
      await _storeAuthTokens(response);
      return response;
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('bedrock_refresh_token');
    try {
      await _authenticatedRequest(
        'POST',
        'auth/logout',
        body: refreshToken != null ? {'refresh_token': refreshToken} : null,
      );
    } catch (_) {
      // Ignore network errors during logout
    }
    await prefs.remove('bedrock_token');
    await prefs.remove('bedrock_refresh_token');
    await prefs.remove('bedrock_user_id');
    await prefs.remove('isLoggedIn');
    await prefs.remove('role');
    await prefs.remove('user_id');
  }

  Future<bool> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('bedrock_refresh_token');
    try {
      final res = await _authenticatedRequest(
        'POST',
        'auth/delete-account',
        body: refreshToken != null ? {'refresh_token': refreshToken} : null,
      );
      await logout();
      return res is Map && res['success'] == true;
    } catch (_) {
      await logout();
      return true;
    }
  }

  Future<bool> recordAppOpen({
    String appVersion = '1.0.0',
    String platform = 'flutter',
    String? deviceId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var persistentDeviceId = deviceId ?? prefs.getString('device_id');
      if (persistentDeviceId == null || persistentDeviceId.isEmpty) {
        persistentDeviceId =
            'dev_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 10000}';
        await prefs.setString('device_id', persistentDeviceId);
      }
      final res = await _authenticatedRequest(
        'POST',
        'keshkart/app-open',
        body: {
          'app_version': appVersion,
          'platform': platform,
          'device_id': persistentDeviceId,
          'metadata': metadata ?? {},
        },
      );
      return res is Map && res['success'] == true;
    } catch (_) {
      return false;
    }
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
    Map<String, dynamic> data, {
    String? mutationId,
    bool preserveError = false,
  }) async {
    return await _authenticatedRequest(
          'POST',
          'collections/$collection',
          body: data,
          mutationId: mutationId,
          preserveError: preserveError,
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
    bool throwOnError = false,
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
      final rows = response['results'] ?? response['data'];
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
    if (throwOnError) throw StateError('Collection could not be loaded.');
    return [];
  }

  Future<List<dynamic>> getStyleRecommendations(String faceShape) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/styles/recommendations',
    ).replace(queryParameters: {'faceShape': faceShape});

    try {
      final response = await _sendWithRetry(
        'GET',
        uri,
        headers: {'X-Project-Key': projectKey},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
      }
      debugPrint(
        'Style Recommendations Failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      debugPrint('Style Recommendations Error: $e');
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

  /// Browser-safe counterpart to [uploadFile].
  ///
  /// Flutter Web cannot turn an XFile into a dart:io File, so browser flows
  /// upload selected image bytes instead.
  Future<String?> uploadBytes(
    Uint8List bytes,
    String path, {
    required String filename,
    String contentType = 'image/jpeg',
    bool retried = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bedrock_token');
    if (token == null || bytes.isEmpty) {
      debugPrint('Bedrock Upload Error: missing access token or image bytes.');
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
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 401 &&
          !retried &&
          await _refreshAccessToken()) {
        return uploadBytes(
          bytes,
          path,
          filename: filename,
          contentType: contentType,
          retried: true,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Bedrock byte upload failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final downloadUrl = data is Map ? data['download_url']?.toString() : null;
      if (downloadUrl == null || downloadUrl.isEmpty) return null;
      return await _verifyDownloadUrl(downloadUrl) ? downloadUrl : null;
    } catch (error) {
      debugPrint('Bedrock byte upload error: $error');
      return null;
    }
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

  /// Returns a short-lived storefront image URL after the barber is approved.
  /// Verification evidence itself remains private in storage.
  Future<String?> getApprovedShopPhotoUrl(String barberId) async {
    try {
      final response = await _authenticatedRequest(
        'GET',
        'keshkart/barbers/$barberId/approved-photo',
      );
      return response is Map ? response['download_url']?.toString() : null;
    } catch (_) {
      return null;
    }
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

  Future<List<Map<String, dynamic>>> getKeshKartSubscriptionPlans() async {
    // Plans are intentionally public. Avoid attaching a stale account token or
    // project header to this read-only catalog request, which keeps the browser
    // request independent from the signed-in session.
    final response = await _publicRequest('GET', 'payments/keshkart/plans');
    if (response is! Map<String, dynamic>) return [];
    final plans = response['plans'];
    if (plans is! List) return [];
    return plans
        .whereType<Map>()
        .map((plan) => Map<String, dynamic>.from(plan))
        .toList();
  }

  Future<Map<String, dynamic>?> getKeshKartSubscription() async {
    return await _authenticatedRequest('GET', 'payments/subscription/current')
        as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> barberAnalytics({
    int days = 30,
    int page = 1,
    String search = '',
    String segment = '',
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/keshkart/barber/analytics/').replace(
      queryParameters: {
        'days': '$days',
        'page': '$page',
        'search': search,
        'segment': segment,
      },
    );
    return await _authenticatedRequest(
          'GET',
          uri.toString(),
          preserveError: true,
        )
        as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> quoteKeshKartSubscription(
    String plan,
    String coupon,
  ) async {
    return await _authenticatedRequest(
          'POST',
          'payments/keshkart/quote',
          body: {'plan': plan, 'coupon': coupon},
          preserveError: true,
        )
        as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> keshKartSeats({
    Map<String, dynamic>? changes,
  }) async {
    return await _authenticatedRequest(
          changes == null ? 'GET' : 'POST',
          'payments/keshkart/seats',
          body: changes,
          preserveError: true,
        )
        as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> createKeshKartRazorpayOrder(
    String planCode, {
    required Map<String, dynamic> quote,
  }) async {
    return await _authenticatedRequest(
          'POST',
          'payments/keshkart/razorpay/create-order',
          body: {
            'plan': planCode,
            'coupon': quote['coupon'],
            'quote_token': quote['quote_token'],
            'terms_accepted': true,
            'terms_version': quote['terms_version'],
          },
          preserveError: true,
        )
        as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> verifyKeshKartRazorpayPayment({
    required String subscriptionId,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    return await _authenticatedRequest(
          'POST',
          'payments/keshkart/razorpay/verify-payment',
          body: {
            'subscription_id': subscriptionId,
            'razorpay_payment_id': paymentId,
            'razorpay_order_id': orderId,
            'razorpay_signature': signature,
          },
        )
        as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> issueAppointmentReceipt(
    String appointmentId,
  ) async {
    return await _authenticatedRequest(
          'POST',
          'keshkart/appointment-receipt',
          body: {'appointmentId': appointmentId},
        )
        as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> checkInWithReceipt(
    String receiptPayload,
  ) async {
    return await _authenticatedRequest(
          'POST',
          'keshkart/check-in',
          body: {'receiptToken': receiptPayload},
        )
        as Map<String, dynamic>?;
  }

  Future<dynamic> _authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retried = false,
    String? mutationId,
    bool preserveError = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bedrock_token');

    if (token == null) {
      debugPrint('Bedrock Error: No access token found. Please login first.');
      return null;
    }

    final effectiveMutationId =
        mutationId ??
        ((method == 'POST' || method == 'PATCH') ? _newMutationId() : null);

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Project-Key': projectKey,
    };
    if (effectiveMutationId != null) {
      headers['X-Mutation-ID'] = effectiveMutationId;
    }

    final cleanPath = path.replaceAll(RegExp(r'^/+|/+$'), '');
    final uri =
        path.contains('http')
            ? Uri.parse(path)
            : Uri.parse('$baseUrl/api/v1/$cleanPath/');

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
          return _authenticatedRequest(
            method,
            path,
            body: body,
            retried: true,
            mutationId: effectiveMutationId,
            preserveError: preserveError,
          );
        }
      } else {
        if (preserveError) {
          try {
            final data = jsonDecode(response.body);
            if (data is Map) {
              return {
                'error':
                    data['error'] ??
                    data['detail'] ??
                    'Request failed. Please try again.',
              };
            }
          } on FormatException {
            debugPrint(
              'Bedrock Request Failed ($method $path): ${response.statusCode} returned non-JSON data.',
            );
            return {
              'error':
                  'The service returned an unexpected response. Please try again later.',
            };
          }
        }
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
    final effectiveHeaders = Map<String, String>.from(headers);
    if ((method == 'POST' ||
            method == 'PATCH' ||
            method == 'PUT' ||
            method == 'DELETE') &&
        !effectiveHeaders.containsKey('X-Mutation-ID')) {
      effectiveHeaders['X-Mutation-ID'] = _newMutationId();
    }

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final encodedBody = body == null ? null : jsonEncode(body);
        switch (method) {
          case 'POST':
            return await http
                .post(uri, headers: effectiveHeaders, body: encodedBody)
                .timeout(requestTimeout);
          case 'PATCH':
            return await http
                .patch(uri, headers: effectiveHeaders, body: encodedBody)
                .timeout(requestTimeout);
          case 'GET':
          case 'GET_RAW':
            return await http
                .get(uri, headers: effectiveHeaders)
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
