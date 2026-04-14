import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/baas_options.dart';
import 'package:my_baas_sdk/my_baas_sdk.dart' as sdk;

class AuthProvider extends ChangeNotifier {
  sdk.User? _currentUser;
  bool _isLoading = false;
  String? _error;

  sdk.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      final client = BaasClient.instance.sdk;
      await client.auth.loadSession();
      _currentUser = client.auth.currentUser;

      // Sync SharedPreferences with SDK state
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString('userId', _currentUser!.id);
        await prefs.setBool('isLoggedIn', true);
        debugPrint("[AUTH] Session Restored: ${_currentUser!.id}");
      } else {
        // If SDK has no session, but prefs think we are logged in, clear prefs
        if (prefs.getBool('isLoggedIn') == true) {
          debugPrint("[AUTH] Session Missing in SDK. Clearing inconsistent Prefs.");
          await prefs.setBool('isLoggedIn', false);
          await prefs.remove('userId');
          await prefs.remove('role');
        }
      }
    } catch (e) {
      debugPrint("Auth Error (Load Session): $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithPhone(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await BaasClient.instance.sdk.auth.signInWithPhone(phone, password);
      _currentUser = BaasClient.instance.sdk.auth.currentUser;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await BaasClient.instance.sdk.auth.sendOtp(
        phone: phone,
        projectKey: DefaultBaasOptions.androidKey,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String phone, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await BaasClient.instance.sdk.auth.verifyOtp(
        phone: phone,
        otp: code,
        projectKey: DefaultBaasOptions.androidKey,
      );
      _currentUser = BaasClient.instance.sdk.auth.currentUser;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await BaasClient.instance.sdk.auth.signOut();
      _currentUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userId');
      await prefs.remove('role');
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSession(Map<String, dynamic> authData) async {
    _isLoading = true;
    notifyListeners();
    try {
      await BaasClient.instance.sdk.auth.handleAuthResponse(authData);
      _currentUser = BaasClient.instance.sdk.auth.currentUser;
      
      // CRITICAL: Ensure SharedPreferences matches the session ID and login state
      if (_currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _currentUser!.id);
        await prefs.setBool('isLoggedIn', true);
        // If authData contains role, save it too
        if (authData.containsKey('role')) {
          await prefs.setString('role', authData['role']);
        } else if (authData['user'] != null && authData['user']['role'] != null) {
          await prefs.setString('role', authData['user']['role']);
        }
        
        // Save phone number if available (Anchor for identity recovery)
        final phone = authData['phone'] ?? authData['phoneNumber'] ?? (authData['user'] != null ? authData['user']['phone'] ?? authData['user']['phoneNumber'] : null);
        if (phone != null) {
          await prefs.setString('userPhone', phone.toString());
          debugPrint("[DIAGNOSTIC] AuthProvider -> Phone Persisted: $phone");
        }
        
        debugPrint("[DIAGNOSTIC] AuthProvider -> Session Persisted (isLoggedIn: true, userId: ${_currentUser!.id})");
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
