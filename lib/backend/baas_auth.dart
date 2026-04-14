import 'package:flutter/foundation.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class BaasAuth {
  /// Get the current session access token.
  static Future<String?> getIdToken() async {
    try {
      final sdk = BaasClient.instance.sdk;
      if (!sdk.auth.isAuthenticated) return null;
      return sdk.apiClient.accessToken;
    } catch (e) {
      debugPrint("Error getting BaaS Token: $e");
      return null;
    }
  }

  static String? get currentUserId =>
      BaasClient.instance.sdk.auth.currentUser?.id;
}
