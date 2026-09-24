// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kesh_kart/layout/keshkart_desktop_frame.dart';
import 'package:flutter/services.dart';
import 'package:kesh_kart/access/role_landing.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/choose.dart';
import 'package:kesh_kart/commons.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? initialRemainingRequests;
  final int? resendCooldownSeconds;
  final int? maxOtpRequests;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.initialRemainingRequests,
    this.resendCooldownSeconds,
    this.maxOtpRequests,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> with CodeAutoFill {
  final TextEditingController _otpController = TextEditingController();
  String otpCode = '';
  int _secondsRemaining = 25;
  int _resendCooldownSeconds = 25;
  int _remainingRequests = 2;
  int _maxOtpRequests = 3;
  int? _retryAfterSeconds;
  Timer? _timer;
  double _iconOpacity = 0.0;
  double _textOpacity = 0.0;
  double _otpShakeOffset = 0.0;
  bool _isVerifying = false;
  bool _hasSubmittedOtp = false;

  @override
  void initState() {
    super.initState();
    _resendCooldownSeconds = widget.resendCooldownSeconds ?? 25;
    _secondsRemaining = _resendCooldownSeconds;
    _remainingRequests = widget.initialRemainingRequests ?? 2;
    _maxOtpRequests = widget.maxOtpRequests ?? 3;

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _iconOpacity = 1.0);
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _textOpacity = 1.0);
    });

    _startResendTimer();
    _startOtpListener();
  }

  void _startResendTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _startOtpListener() async {
    try {
      await SmsAutoFill().listenForCode();
    } catch (e) {
      debugPrint('SMS autofill listener failed: $e');
    }
  }

  @override
  void codeUpdated() {
    final smsCode = code;
    if (smsCode == null || smsCode.isEmpty) return;

    final digits = smsCode.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return;

    final normalized = digits.substring(0, 6);
    _otpController.text = normalized;
    _onOtpChanged(normalized);
  }

  void _onOtpChanged(String value) {
    otpCode = value.trim();
    if (mounted) {
      setState(() {});
    }
    if (otpCode.length == 6) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp({bool showLengthError = false}) async {
    if (_isVerifying || _hasSubmittedOtp) return;

    if (otpCode.length != 6) {
      if (showLengthError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
        );
      }
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final bedrockResponse = await BedrockClient().verifyOtp(
        widget.phoneNumber,
        otpCode,
      );
      if (bedrockResponse == null) {
        throw Exception('OTP verification failed');
      }

      _hasSubmittedOtp = true;
      final bool isNewUser = bedrockResponse['is_new_user'] ?? false;
      final String bedrockUserId = bedrockResponse['user_id'] ?? '';

      if (!mounted) return;

      if (isNewUser) {
        _goToRegistration(bedrockUserId);
        return;
      }

      final users = await BedrockClient().queryCollection(
        'users',
        params: {'uid': bedrockUserId},
      );

      if (!mounted) return;

      if (users.isEmpty) {
        _goToRegistration(bedrockUserId);
        return;
      }

      final userDataWrapper = users.first;
      final userData = userDataWrapper['data'] ?? {};
      final userType = userData['userType'] ?? '';
      final profileCompleted = userData['profileCompleted'] == true;

      if (!profileCompleted) {
        _goToRegistration(bedrockUserId);
        return;
      }

      await _storeProfile(bedrockUserId, userType, userData);
      if (userType == 'barber' && !kIsWeb) {
        await NotificationService.requestPermissionAndSyncToken();
      }

      if (!mounted) return;

      if (userType == 'barber') {
        Navigator.pushReplacement(context, slideUpRoute(RoleLanding.barber()));
      } else if (userType == 'customer') {
        // Android is intentionally barber-only. Customer accounts are handed
        // off to keshkart.com rather than loading customer functionality.
        Navigator.pushReplacement(
          context,
          slideUpRoute(RoleLanding.customer()),
        );
      } else {
        _goToRegistration(bedrockUserId);
      }
    } catch (e) {
      _hasSubmittedOtp = false;
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OTP verification failed: $e')));
      await _wrongOtpFeedback();
    }
  }

  Future<void> _wrongOtpFeedback() async {
    await HapticFeedback.mediumImpact();
    for (final offset in const [10.0, -10.0, 7.0, -7.0, 0.0]) {
      if (!mounted) return;
      setState(() => _otpShakeOffset = offset);
      await Future.delayed(const Duration(milliseconds: 45));
    }
  }

  Future<void> _storeProfile(
    String userId,
    String userType,
    Map<String, dynamic> userData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('role', userType);
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('name', userData['name'] ?? '');
    await prefs.setString('barberName', userData['name'] ?? '');
    await prefs.setString('phone', userData['phone'] ?? '');
    await prefs.setString('email', userData['email'] ?? '');
    await prefs.setString('shopName', userData['shopName'] ?? '');

    if (userData['location'] != null) {
      final location = userData['location'];
      await prefs.setDouble('lat', location['lat'] ?? 0.0);
      await prefs.setDouble('lng', location['lng'] ?? 0.0);
      final city = location['city']?.toString().trim() ?? '';
      final pincode = location['pincode']?.toString().trim() ?? '';
      final label = [
        city,
        pincode,
      ].where((part) => part.isNotEmpty).join(' - ');
      if (label.isNotEmpty) {
        await prefs.setString('locationLabel', label);
      } else if ((location['label']?.toString().trim() ?? '').isNotEmpty) {
        await prefs.setString('locationLabel', location['label'].toString());
      }
    }

    await prefs.setBool('isActive', userData['isActive'] ?? false);
    await prefs.setStringList(
      'shopPhotos',
      List<String>.from(userData['shopPhotos'] ?? []),
    );
  }

  void _goToRegistration(String userId) {
    Navigator.pushReplacement(
      context,
      slideUpRoute(Choose(phoneNumber: widget.phoneNumber, userId: userId)),
    );
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isVerifying) return;
    if (_remainingRequests <= 0) {
      _showLimitMessage();
      return;
    }

    if (_remainingRequests == 1) {
      final shouldContinue = await _confirmLastOtpRequest();
      if (shouldContinue != true) return;
    }

    final response = await BedrockClient().requestOtp(widget.phoneNumber);
    if (!mounted) return;

    if (response == null || response['success'] != true) {
      _applyOtpRequestState(response);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_otpRequestError(response))));
      return;
    }

    _otpController.clear();
    _applyOtpRequestState(response);
    setState(() {
      otpCode = '';
      _hasSubmittedOtp = false;
      _isVerifying = false;
      _secondsRemaining = _resendCooldownSeconds;
    });
    _startResendTimer();
    _startOtpListener();
  }

  void _applyOtpRequestState(Map<String, dynamic>? response) {
    if (response == null) return;
    final remaining = response['remaining_requests'];
    final cooldown = response['cooldown_seconds'];
    final maxRequests = response['max_requests'];
    final retryAfter = response['retry_after_seconds'];

    if (remaining is int) _remainingRequests = remaining;
    if (cooldown is int) _resendCooldownSeconds = cooldown;
    if (maxRequests is int) _maxOtpRequests = maxRequests;
    if (retryAfter is int) _retryAfterSeconds = retryAfter;
  }

  String _otpRequestError(Map<String, dynamic>? response) {
    if (response == null) return 'Failed to resend OTP';
    final error = response['error']?.toString();
    if (error != null && error.isNotEmpty) return error;
    return 'Failed to resend OTP';
  }

  Future<bool?> _confirmLastOtpRequest() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Last OTP request',
              style: TextStyle(color: Color(0xFF091426)),
            ),
            content: const Text(
              'This is your last OTP request. If you do not verify with this OTP, you will need to wait 4 hours before requesting another code.',
              style: TextStyle(color: Color(0xFF45474C)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send last OTP'),
              ),
            ],
          ),
    );
  }

  void _showLimitMessage() {
    final hours =
        _retryAfterSeconds == null
            ? '4 hours'
            : '${((_retryAfterSeconds! / 3600).ceil()).clamp(1, 4)} hours';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP request limit reached. Try again in $hours.'),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Verify OTP',
          style: TextStyle(
            color: Color(0xFF091426),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return KeshKartDesktopFrame(
            maxWidth: 560,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        AnimatedOpacity(
                          opacity: _iconOpacity,
                          duration: const Duration(milliseconds: 600),
                          child: Image.asset(
                            'assets/images/otp.png',
                            height: 200,
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedOpacity(
                          opacity: _textOpacity,
                          duration: const Duration(milliseconds: 600),
                          child: Text(
                            'Enter the OTP sent to\n${widget.phoneNumber}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        buildOtpLoginUI(),
                        const SizedBox(height: 35),
                        Center(
                          child: AnimatedGradientBorder(
                            borderSize: 2,
                            glowSize: 10,
                            gradientColors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.purple.shade50,
                            ],
                            borderRadius: const BorderRadius.all(
                              Radius.circular(999),
                            ),
                            child: InkWell(
                              onTap:
                                  _isVerifying
                                      ? null
                                      : () => _verifyOtp(showLengthError: true),
                              child: Opacity(
                                opacity: _isVerifying ? 0.6 : 1,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF091426),
                                    shape: BoxShape.circle,
                                  ),
                                  child:
                                      _isVerifying
                                          ? const Padding(
                                            padding: EdgeInsets.all(18),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Icon(
                                            CupertinoIcons.arrow_right,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildOtpLoginUI() {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 45),
          transform: Matrix4.translationValues(_otpShakeOffset, 0, 0),
          child: PinCodeTextField(
            appContext: context,
            controller: _otpController,
            autoDisposeControllers: false,
            length: 6,
            keyboardType: TextInputType.number,
            autoFocus: true,
            autoDismissKeyboard: true,
            enablePinAutofill: true,
            animationType: AnimationType.fade,
            textStyle: const TextStyle(color: Color(0xFF091426), fontSize: 20),
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(10),
              fieldHeight: 50,
              fieldWidth: 40,
              activeColor: const Color(0xFF091426),
              selectedColor: const Color(0xFF0A66C2),
              inactiveColor: Colors.grey.shade300,
            ),
            backgroundColor: const Color(0xFFF8F9FA),
            enableActiveFill: false,
            onChanged: _onOtpChanged,
            onCompleted: (value) {
              otpCode = value.trim();
              _verifyOtp();
            },
          ),
        ),
        if (_isVerifying) ...[
          const SizedBox(height: 12),
          const Text(
            'Verifying OTP...',
            style: TextStyle(color: Color(0xFF45474C)),
          ),
        ],
        const SizedBox(height: 10),
        _secondsRemaining > 0
            ? Text(
              'Resend OTP in $_secondsRemaining s',
              style: const TextStyle(color: Colors.black54),
            )
            : _remainingRequests <= 0
            ? Text(
              'OTP request limit reached. Try again after 4 hours.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            )
            : TextButton(
              onPressed: _resendOtp,
              child: const Text(
                'Resend OTP',
                style: TextStyle(color: Color(0xFF091426)),
              ),
            ),
        const SizedBox(height: 6),
        Text(
          _remainingRequests == 1
              ? 'Last OTP request remaining'
              : '$_remainingRequests of $_maxOtpRequests OTP requests remaining',
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                _remainingRequests <= 1
                    ? Colors.orange.shade700
                    : Colors.black45,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
