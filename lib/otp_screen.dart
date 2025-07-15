// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/choose.dart';
import 'package:kesh_kart/commons.dart';
import 'package:kesh_kart/customer/home.dart';

class OTPScreen extends StatefulWidget {
  final bool isSignUp;
  final String? userName;
  final String? userId;
  final String phoneNumber;
  final String verificationId;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.isSignUp,
    this.userName,
    this.userId,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  String otpCode = '';
  int _secondsRemaining = 30;
  late final Timer _timer;
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
      setState(() => _iconOpacity = 1.0);
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() => _textOpacity = 1.0);
    });

    _startResendTimer();
  }

  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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
                    Colors.purple.shade50,
                  ],
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: InkWell(
                    onTap: () async {
                      if (otpCode.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid 6-digit OTP'),
                          ),
                        );
                        return;
                      }

                      try {
                        PhoneAuthCredential credential =
                            PhoneAuthProvider.credential(
                              verificationId: widget.verificationId,
                              smsCode: otpCode,
                            );

                        await FirebaseAuth.instance.signInWithCredential(
                          credential,
                        );

                        final user = FirebaseAuth.instance.currentUser;
                        final uid = user?.uid;
                        final phone = '+91${widget.phoneNumber}';

                        if (widget.isSignUp) {
                          // 🔹 New user → Go to role selection & registration
                          Navigator.pushReplacement(
                            context,
                            slideUpRoute(
                              Choose(
                                phoneNumber: widget.phoneNumber,
                                userId: uid ?? '',
                              ),
                            ),
                          );
                        } else {
                          // 🔹 Existing user → Fetch details and route to home
                          final docSnapshot =
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .where('phone', isEqualTo: phone)
                                  .limit(1)
                                  .get();

                          if (docSnapshot.docs.isNotEmpty) {
                            final userData = docSnapshot.docs.first.data();
                            final userType = userData['userType'] ?? '';
                            final profileCompleted =
                                userData['profileCompleted'] == true;

                            if (!profileCompleted) {
                              // Doc exists but incomplete (fail-safe)
                              Navigator.pushReplacement(
                                context,
                                slideUpRoute(
                                  Choose(
                                    phoneNumber: widget.phoneNumber,
                                    userId: uid ?? '',
                                  ),
                                ),
                              );
                            } else if (userType == 'barber') {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString('userId', uid ?? '');
                              await prefs.setString('role', userType);
                              await prefs.setBool('isLoggedIn', true);

                              Navigator.pushReplacement(
                                context,
                                slideUpRoute(const BarberHome()),
                              );
                            } else if (userType == 'customer') {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString('userId', uid ?? '');
                              await prefs.setString('role', userType);
                              await prefs.setBool('isLoggedIn', true);

                              Navigator.pushReplacement(
                                context,
                                slideUpRoute(const CustomerHome()),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Invalid user type."),
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "User not found. Please sign up.",
                                ),
                              ),
                            );
                          }
                        }
                      } catch (e) {
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
          animationType: AnimationType.fade,
          textStyle: const TextStyle(color: Colors.white, fontSize: 20),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(10),
            fieldHeight: 50,
            fieldWidth: 40,
            activeColor: Colors.white,
            selectedColor: Colors.purpleAccent,
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
}
