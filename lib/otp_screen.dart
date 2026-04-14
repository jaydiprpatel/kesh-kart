// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/choose.dart';
import 'package:kesh_kart/commons.dart';
import 'package:kesh_kart/customer/home.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:kesh_kart/providers/auth_provider.dart' as prov;

class OTPScreen extends StatefulWidget {
  final bool isSignUp;
  final String? userName;
  final String? userId;
  final String phoneNumber;
  final String verificationId;
  final bool isFirebase;

  final bool isSilentFallback;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.isSignUp,
    this.isFirebase = false,
    this.isSilentFallback = false,
    this.userName,
    this.userId,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  String otpCode = '';
  int _secondsRemaining = 30;
  Timer? _timer;
  double _iconOpacity = 0.0;
  double _textOpacity = 0.0;

  bool _showPasswordLogin = false;
  String password = '';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    debugPrint("🚨 IS SIGN UP RECEIVED: ${widget.isSignUp}");

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _iconOpacity = 1.0);
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _textOpacity = 1.0);
    });

    _startResendTimer();
  }

  void _startResendTimer() {
    _timer?.cancel(); // Safety check
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Verify OTP',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              AnimatedOpacity(
                opacity: _iconOpacity,
                duration: const Duration(milliseconds: 600),
                child: Image.asset('assets/images/otp.png', height: 200),
              ),
              const SizedBox(height: 20),
              AnimatedOpacity(
                opacity: _textOpacity,
                duration: const Duration(milliseconds: 600),
                child: Text(
                  'Enter the ${_showPasswordLogin ? "password" : "OTP"} sent to\n+91 ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _showPasswordLogin ? buildPasswordLoginUI() : buildOtpLoginUI(),

              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showPasswordLogin = !_showPasswordLogin;
                  });
                },
                child: Text(
                  _showPasswordLogin ? 'Login with OTP' : 'Login with Password',
                  style: const TextStyle(
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: AnimatedGradientBorder(
                  borderSize: 2,
                  glowSize: 10,
                  gradientColors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF00D189),
                  ],
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: InkWell(
                    onTap: () async {
                      if (_showPasswordLogin) {
                        if (password.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid password'),
                            ),
                          );
                          return;
                        }

                        try {
                          final baas = BaasClient.instance;
                          await baas.sdk.auth.signInWithPhone(
                            widget.phoneNumber,
                            password,
                          );

                          final user = baas.sdk.auth.currentUser;
                          final uid = user?.id ?? '';

                          // 🔍 Check if profile is completed
                          final userDoc =
                              await BaasClient.collection(
                                'users',
                              ).doc(uid).get();

                          if (userDoc.exists) {
                            final userData =
                                userDoc.data() as Map<String, dynamic>;
                            final userType = userData['userType'] ?? '';

                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('userId', uid);
                            await prefs.setString('role', userType);
                            await prefs.setBool('isLoggedIn', true);

                            // Update FCM Token after login
                            try {
                              String? fcmToken =
                                  await FirebaseMessaging.instance.getToken();
                              if (fcmToken != null) {
                                await BaasClient.instance.updateFcmToken(
                                  fcmToken,
                                );
                                debugPrint("OTP: FCM Token updated on login");
                              }
                            } catch (fcmError) {
                              debugPrint("OTP: FCM Trace Error: $fcmError");
                            }

                            if (userType == 'barber') {
                              Navigator.pushReplacement(
                                context,
                                slideUpRoute(const BarberHome()),
                              );
                            } else {
                              Navigator.pushReplacement(
                                context,
                                slideUpRoute(const CustomerHome()),
                              );
                            }
                          } else {
                            // This shouldn't happen if password login succeeded but doc missing,
                            // but handle by redirecting to Choose.
                            Navigator.pushReplacement(
                              context,
                              slideUpRoute(
                                Choose(
                                  phoneNumber: widget.phoneNumber,
                                  userId: uid,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Login failed: $e')),
                          );
                        }
                        return;
                      }

                      if (otpCode.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid 6-digit OTP'),
                          ),
                        );
                        return;
                      }

                      try {
                        if (widget.isFirebase) {
                          final auth = FirebaseAuth.instance;
                          final credential = PhoneAuthProvider.credential(
                            verificationId: widget.verificationId,
                            smsCode: otpCode,
                          );
                          final userCredential = await auth
                              .signInWithCredential(credential);
                          final idToken =
                              await userCredential.user?.getIdToken();
                          if (idToken != null) {
                            await _exchangeFirebaseToken(
                              idToken,
                              '+91${widget.phoneNumber}',
                            );
                          }
                          return;
                        }

                        /* 
                           REPLACED FIREBASE AUTH WITH BAAS SDK
                        */
                        final baas = BaasClient.instance;

                        if (widget.isSilentFallback) {
                          // Get Installation ID (Device ID)
                          final prefs = await SharedPreferences.getInstance();
                          String? deviceId = prefs.getString('installation_id');

                          // Ensure deviceId is never null for the backend
                          if (deviceId == null) {
                            deviceId = const Uuid().v4();
                            await prefs.setString('installation_id', deviceId);
                          }

                          // Promote to non-nullable for the SDK call
                          final String safeDeviceId = deviceId;

                          debugPrint(
                            "[OTP] Silent Fallback Completing: Nonce=${widget.verificationId}, Code=$otpCode, DeviceID=$safeDeviceId",
                          );

                          if (widget.verificationId.isEmpty) {
                            debugPrint(
                              "[OTP] Nonce is empty. Falling back to traditional OTP.",
                            );
                          } else {
                            try {
                              final result = await baas.sdk.auth
                                  .completeSilentVerification(
                                    nonce: widget.verificationId,
                                    code: otpCode,
                                    deviceId: safeDeviceId,
                                  );

                              if (result['access_token'] != null) {
                                final uid = result['user_id'];
                                await _routeExistingUser(uid);
                                return;
                              }
                            } catch (e) {
                              debugPrint(
                                "[OTP] Silent Verification failed: $e. Falling back to traditional OTP.",
                              );
                            }
                          }
                        }

                        final auth = Provider.of<prov.AuthProvider>(
                          context,
                          listen: false,
                        );
                        final success = await auth.verifyOtp(
                          widget.phoneNumber.startsWith('+91')
                              ? widget.phoneNumber
                              : '+91${widget.phoneNumber}',
                          otpCode,
                        );

                        if (success) {
                          final uid = auth.currentUser!.id;
                          await _routeExistingUser(uid);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'OTP verification failed: ${auth.error}',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint(
                          "🔴 OTP Verification Exception: $e",
                        ); // Debug
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('OTP verification failed: $e'),
                          ),
                        );
                      }
                    },

                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.arrow_right,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildOtpLoginUI() {
    return Column(
      children: [
        PinCodeTextField(
          appContext: context,
          length: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          animationType: AnimationType.fade,
          textStyle: const TextStyle(color: Colors.white, fontSize: 20),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(10),
            fieldHeight: 50,
            fieldWidth: 40,
            activeColor: Colors.white,
            selectedColor: const Color(0xFF00D189),
            inactiveColor: Colors.white38,
          ),
          backgroundColor: Colors.black,
          enableActiveFill: false,
          onChanged: (value) => setState(() => otpCode = value),
        ),
        const SizedBox(height: 10),
        _secondsRemaining > 0
            ? Text(
              'Resend OTP in $_secondsRemaining s',
              style: const TextStyle(color: Colors.white54),
            )
            : TextButton(
              onPressed: () {
                setState(() {
                  _secondsRemaining = 30;
                  _startResendTimer();
                });
              },
              child: const Text(
                'Resend OTP',
                style: TextStyle(color: Colors.white),
              ),
            ),
      ],
    );
  }

  Widget buildPasswordLoginUI() {
    return TextField(
      onChanged: (value) => password = value,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white10,
        hintText: 'Enter Password',
        hintStyle: const TextStyle(color: Colors.white38),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white54,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _exchangeFirebaseToken(
    String idToken,
    String phoneNumber,
  ) async {
    try {
      final baas = BaasClient.instance;

      // Get/Generate Device ID
      final prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('installation_id') ?? const Uuid().v4();
      await prefs.setString('installation_id', deviceId);

      debugPrint("[OTP] Exchanging Firebase Token for phone: $phoneNumber");

      final result = await baas.sdk.auth.signInWithFirebase(
        idToken: idToken,
        deviceId: deviceId,
      );

      final String uid = result['user_id'];
      final bool isNewUser = result['is_new_user'] ?? false;

      // Securely Store Session via AuthProvider
      final auth = Provider.of<prov.AuthProvider>(context, listen: false);
      final sessionData = Map<String, dynamic>.from(result);
      sessionData['phone'] = phoneNumber;
      await auth.updateSession(sessionData);

      if (isNewUser) {
        Navigator.pushReplacement(
          context,
          slideUpRoute(
            Choose(
              phoneNumber:
                  phoneNumber.startsWith('+91')
                      ? phoneNumber.substring(3)
                      : phoneNumber,
              userId: uid,
            ),
          ),
        );
      } else {
        await _routeExistingUser(uid);
      }
    } catch (e) {
      debugPrint("🔴 Error exchanging Firebase token: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Auth Exchange Error: $e")));
    }
  }

  Future<void> _routeExistingUser(String uid) async {
    final userDoc = await BaasClient.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final userType = userData['userType'] ?? 'customer';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', userType);
      await prefs.setString('userId', uid);

      if (userType == 'barber') {
        Navigator.pushReplacement(context, slideUpRoute(const BarberHome()));
      } else {
        Navigator.pushReplacement(context, slideUpRoute(const CustomerHome()));
      }
    } else {
      Navigator.pushReplacement(
        context,
        slideUpRoute(Choose(phoneNumber: widget.phoneNumber, userId: uid)),
      );
    }
  }
}
