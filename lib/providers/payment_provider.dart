import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../backend/baas_auth.dart';
import '../backend/baas_env_config.dart';

class PaymentProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  String? _approvalUrl;
  int? _subscriptionId;
  String _status = 'none';

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get approvalUrl => _approvalUrl;
  String get status => _status;
  int? get subscriptionId => _subscriptionId;

  Future<Map<String, String>> _authHeaders() async {
    final token = await BaasAuth.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> createSubscription(String userId, {String plan = 'pro'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${BaasEnvConfig.current.apiUrl}/api/payments/subscription/create/'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'plan': plan,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        _approvalUrl = data['approval_url'];
        _subscriptionId = data['subscription_id'];
        _status = data['status'] ?? 'pending';
      } else {
        _error = data['error'] ?? 'Subscription creation failed';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? _pollingStartTime;

  Future<bool> refreshCurrentSubscription() async {
    _error = null;
    notifyListeners();

    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${BaasEnvConfig.current.apiUrl}/api/payments/subscription/current/'),
        headers: headers,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _subscriptionId = data['subscription_id'];
        _status = (data['status'] ?? 'none').toString();
        return data['is_access_active'] == true;
      }

      _error = data['error'] ?? 'Could not fetch subscription status';
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }

    return false;
  }

  Future<void> pollStatus() async {
    if (_subscriptionId == null) return;
    
    // Safety: Polling Timeout (5 minutes)
    if (_pollingStartTime == null) {
      _pollingStartTime = DateTime.now();
    } else if (DateTime.now().difference(_pollingStartTime!).inMinutes > 5) {
      debugPrint("Pollling Timeout: Stopping auto-check for Subscription $_subscriptionId");
      _status = 'timeout';
      notifyListeners();
      return;
    }

    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${BaasEnvConfig.current.apiUrl}/api/payments/subscription/status/$_subscriptionId/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newStatus = data['status'];
        if (newStatus != _status) {
          _status = newStatus;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Polling error: $e");
    }
  }

  void reset() {
    _approvalUrl = null;
    _subscriptionId = null;
    _status = 'none';
    _error = null;
    _pollingStartTime = null;
    notifyListeners();
  }
}
