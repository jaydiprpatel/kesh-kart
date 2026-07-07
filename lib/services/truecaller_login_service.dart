import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truecaller_sdk/truecaller_sdk.dart';

class TruecallerLoginResult {
  const TruecallerLoginResult({
    this.accessToken,
    this.authorizationCode,
    this.codeVerifier,
    this.errorMessage,
  });

  final String? accessToken;
  final String? authorizationCode;
  final String? codeVerifier;
  final String? errorMessage;

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
    debugPrint('[Truecaller SDK Diagnostic] Checking usability...');
    if (defaultTargetPlatform != TargetPlatform.android) {
      debugPrint(
        '[Truecaller SDK Diagnostic] Platform is not Android. Current platform: $defaultTargetPlatform',
      );
      return false;
    }
    try {
      debugPrint('[Truecaller SDK Diagnostic] Initializing SDK...');
      await initialize();
      debugPrint(
        '[Truecaller SDK Diagnostic] SDK Initialized. Checking isOAuthFlowUsable...',
      );
      final bool usable = await TcSdk.isOAuthFlowUsable == true;
      debugPrint(
        '[Truecaller SDK Diagnostic] isOAuthFlowUsable result: $usable',
      );
      return usable;
    } catch (e, stackTrace) {
      debugPrint(
        '[Truecaller SDK Diagnostic] Exception during usability check: $e',
      );
      debugPrint(
        '[Truecaller SDK Diagnostic] Usability check stack trace: $stackTrace',
      );
      return false;
    }
  }

  Future<TruecallerLoginResult?> startLogin() async {
    debugPrint('[Truecaller SDK Diagnostic] startLogin() called');
    final bool usable = await isUsable;
    if (!usable) {
      debugPrint(
        '[Truecaller SDK Diagnostic] Truecaller is not usable on this device.',
      );
      return const TruecallerLoginResult(
        errorMessage:
            'Truecaller app is not ready on this device. Please continue with OTP.',
      );
    }
    if (_pendingLogin != null && !_pendingLogin!.isCompleted) {
      debugPrint(
        '[Truecaller SDK Diagnostic] startLogin() failed: login is already in progress',
      );
      return const TruecallerLoginResult(
        errorMessage: 'Truecaller login is already in progress.',
      );
    }

    _pendingLogin = Completer<TruecallerLoginResult?>();
    _oauthState = 'keshkart-${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[Truecaller SDK Diagnostic] Setting OAuth State: $_oauthState');

    try {
      unawaited(TcSdk.setOAuthState(_oauthState!));
      unawaited(TcSdk.setOAuthScopes(['phone', 'openid']));
      debugPrint(
        '[Truecaller SDK Diagnostic] Scopes and State configured successfully',
      );

      final codeVerifier = await TcSdk.generateRandomCodeVerifier;
      debugPrint(
        '[Truecaller SDK Diagnostic] Generated Code Verifier: $codeVerifier',
      );
      final codeChallenge = await TcSdk.generateCodeChallenge(codeVerifier);
      debugPrint(
        '[Truecaller SDK Diagnostic] Generated Code Challenge: $codeChallenge',
      );

      if (codeChallenge == null || codeChallenge.isEmpty) {
        debugPrint(
          '[Truecaller SDK Diagnostic] Code challenge generation failed (null or empty)',
        );
        return _finishWithResult(
          const TruecallerLoginResult(
            errorMessage:
                'Truecaller could not start on this device. Please continue with OTP.',
          ),
        );
      }

      _codeVerifier = codeVerifier;
      unawaited(TcSdk.setCodeChallenge(codeChallenge));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      debugPrint(
        '[Truecaller SDK Diagnostic] Code Challenge set. Launching Truecaller authorization sheet...',
      );

      unawaited(TcSdk.getAuthorizationCode);
      debugPrint(
        '[Truecaller SDK Diagnostic] getAuthorizationCode task dispatched',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[Truecaller SDK Diagnostic] Exception during startLogin configuration: $e',
      );
      debugPrint(
        '[Truecaller SDK Diagnostic] startLogin stack trace: $stackTrace',
      );
      return _finishWithResult(
        TruecallerLoginResult(
          errorMessage: 'Truecaller could not start: ${e.toString()}',
        ),
      );
    }

    return _pendingLogin!.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        debugPrint(
          '[Truecaller SDK Diagnostic] Login flow timed out after 90 seconds',
        );
        const result = TruecallerLoginResult(
          errorMessage: 'Truecaller login timed out. Please continue with OTP.',
        );
        _complete(result);
        return result;
      },
    );
  }

  void _handleCallback(dynamic callback) {
    debugPrint('[Truecaller SDK Diagnostic] _handleCallback invoked');
    if (callback == null) {
      debugPrint('[Truecaller SDK Diagnostic] Callback received is null');
      return;
    }

    // Log details of the callback payload safely
    final resultVal = callback.result;
    final errorVal = callback.error;
    final exceptionVal = callback.exception;

    debugPrint('[Truecaller SDK Diagnostic] Callback Result: $resultVal');
    if (errorVal != null) {
      debugPrint(
        '[Truecaller SDK Diagnostic] Callback Error: message="${errorVal.message}", code=${errorVal.code}',
      );
    }
    if (exceptionVal != null) {
      debugPrint(
        '[Truecaller SDK Diagnostic] Callback Exception: message="${exceptionVal.message}"',
      );
    }

    if (_pendingLogin == null || _pendingLogin!.isCompleted) {
      debugPrint(
        '[Truecaller SDK Diagnostic] Callback ignored: no pending login completer is active',
      );
      return;
    }

    switch (resultVal) {
      case TcSdkCallbackResult.success:
        final oAuthData = callback.tcOAuthData;
        final receivedState = oAuthData?.state?.toString();
        debugPrint(
          '[Truecaller SDK Diagnostic] Success. State: $receivedState, AuthCode: ${oAuthData?.authorizationCode?.toString()}',
        );

        if (_oauthState != null && receivedState != _oauthState) {
          debugPrint(
            '[Truecaller SDK Diagnostic] State mismatch error! Expected: $_oauthState, Received: $receivedState',
          );
          _complete(
            const TruecallerLoginResult(
              errorMessage:
                  'Truecaller returned an invalid login state. Please try again.',
            ),
          );
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
        debugPrint(
          '[Truecaller SDK Diagnostic] Verification Complete. AccessToken: ${callback.accessToken?.toString()}',
        );
        _complete(
          TruecallerLoginResult(accessToken: callback.accessToken?.toString()),
        );
        break;
      case TcSdkCallbackResult.verifiedBefore:
        debugPrint(
          '[Truecaller SDK Diagnostic] Verified Before. AccessToken: ${callback.profile?.accessToken?.toString()}',
        );
        _complete(
          TruecallerLoginResult(
            accessToken: callback.profile?.accessToken?.toString(),
          ),
        );
        break;
      case TcSdkCallbackResult.failure:
        final errMsg =
            errorVal?.message?.toString() ??
            'Truecaller authorization was not completed.';
        final errCode = errorVal?.code;
        debugPrint(
          '[Truecaller SDK Diagnostic] Failure callback received: code=$errCode, message="$errMsg"',
        );
        _complete(
          TruecallerLoginResult(errorMessage: '$errMsg (Error code: $errCode)'),
        );
        break;
      case TcSdkCallbackResult.verification:
        debugPrint(
          '[Truecaller SDK Diagnostic] Verification callback received: manual verification required',
        );
        _complete(
          const TruecallerLoginResult(
            errorMessage:
                'Truecaller needs manual verification. Please continue with OTP.',
          ),
        );
        break;
      case TcSdkCallbackResult.exception:
        final exMsg =
            exceptionVal?.message?.toString() ??
            'Truecaller failed to verify this device.';
        debugPrint(
          '[Truecaller SDK Diagnostic] Exception callback received: message="$exMsg"',
        );
        _complete(TruecallerLoginResult(errorMessage: exMsg));
        break;
      default:
        debugPrint(
          '[Truecaller SDK Diagnostic] Unknown/unhandled callback result: $resultVal',
        );
        break;
    }
  }

  Future<TruecallerLoginResult?> _finishWithResult(
    TruecallerLoginResult result,
  ) {
    final completer = _pendingLogin;
    _complete(result);
    return completer?.future ?? Future.value(result);
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
