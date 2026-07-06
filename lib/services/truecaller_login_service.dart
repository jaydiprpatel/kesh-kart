import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truecaller_sdk/truecaller_sdk.dart';

class TruecallerLoginResult {
  const TruecallerLoginResult({
    this.accessToken,
    this.authorizationCode,
    this.codeVerifier,
  });

  final String? accessToken;
  final String? authorizationCode;
  final String? codeVerifier;

  bool get hasToken => accessToken != null && accessToken!.isNotEmpty;
  bool get hasAuthorizationCode =>
      authorizationCode != null &&
      authorizationCode!.isNotEmpty &&
      codeVerifier != null &&
      codeVerifier!.isNotEmpty;
}

class TruecallerLoginService {
  StreamSubscription? _subscription;
  Completer<TruecallerLoginResult?>? _pendingLogin;
  String? _oauthState;
  String? _codeVerifier;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || defaultTargetPlatform != TargetPlatform.android) return;

    TcSdk.initializeSDK(
      sdkOption: TcSdkOptions.OPTION_VERIFY_ONLY_TC_USERS,
      consentMode: TcSdkOptions.CONSENT_MODE_BOTTOMSHEET,
      ctaText: TcSdkOptions.CTA_TEXT_CONTINUE,
      buttonShapeOption: TcSdkOptions.BUTTON_SHAPE_ROUNDED,
    );
    _subscription = TcSdk.streamCallbackData.listen(_handleCallback);
    _initialized = true;
  }

  Future<bool> get isUsable async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    await initialize();
    return await TcSdk.isOAuthFlowUsable == true;
  }

  Future<TruecallerLoginResult?> startLogin() async {
    if (!await isUsable) return null;
    if (_pendingLogin != null && !_pendingLogin!.isCompleted) return null;

    _pendingLogin = Completer<TruecallerLoginResult?>();
    _oauthState = 'keshkart-${DateTime.now().millisecondsSinceEpoch}';
    TcSdk.setOAuthState(_oauthState!);
    TcSdk.setOAuthScopes(['profile', 'phone', 'openid']);

    final codeVerifier = await TcSdk.generateRandomCodeVerifier;
    final codeChallenge = await TcSdk.generateCodeChallenge(codeVerifier);
    if (codeChallenge == null || codeChallenge.isEmpty) {
      _complete(null);
      return null;
    }

    _codeVerifier = codeVerifier;
    TcSdk.setCodeChallenge(codeChallenge);
    TcSdk.getAuthorizationCode;

    return _pendingLogin!.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        _complete(null);
        return null;
      },
    );
  }

  void _handleCallback(dynamic callback) {
    if (_pendingLogin == null || _pendingLogin!.isCompleted) return;

    switch (callback.result) {
      case TcSdkCallbackResult.success:
        final oAuthData = callback.tcOAuthData;
        final receivedState = oAuthData?.state?.toString();
        if (_oauthState != null && receivedState != _oauthState) {
          _complete(null);
          return;
        }
        _complete(
          TruecallerLoginResult(
            authorizationCode: oAuthData?.authorizationCode?.toString(),
            codeVerifier: _codeVerifier,
          ),
        );
        break;
      case TcSdkCallbackResult.verificationComplete:
        _complete(
          TruecallerLoginResult(accessToken: callback.accessToken?.toString()),
        );
        break;
      case TcSdkCallbackResult.verifiedBefore:
        _complete(
          TruecallerLoginResult(
            accessToken: callback.profile?.accessToken?.toString(),
          ),
        );
        break;
      case TcSdkCallbackResult.failure:
      case TcSdkCallbackResult.verification:
      case TcSdkCallbackResult.exception:
        _complete(null);
        break;
      default:
        break;
    }
  }

  void _complete(TruecallerLoginResult? result) {
    if (_pendingLogin != null && !_pendingLogin!.isCompleted) {
      _pendingLogin!.complete(result);
    }
    _pendingLogin = null;
    _oauthState = null;
    _codeVerifier = null;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _complete(null);
  }
}
