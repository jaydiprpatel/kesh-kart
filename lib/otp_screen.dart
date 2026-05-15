// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/choose.dart';
import 'package:kesh_kart/commons.dart';
import 'package:kesh_kart/customer/home.dart';
import 'package:kesh_kart/bedrock_client.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
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

  @override
  void initState() {
    super.initState();

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
                  'Enter the OTP sent to\n${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              buildOtpLoginUI(),

              const SizedBox(height: 10),
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
                        final bedrockResponse = await BedrockClient().verifyOtp(
                          widget.phoneNumber,
                          otpCode,
                        );
                        if (bedrockResponse == null) {
                          throw Exception("OTP verification failed");
                        }

                        final bool isNewUser =
                            bedrockResponse['is_new_user'] ?? false;
                        final String bedrockUserId =
                            bedrockResponse['user_id'] ?? '';

                        if (isNewUser) {
                          // 🔹 New user → Go to role selection & registration
                          Navigator.pushReplacement(
                            context,
                            slideUpRoute(
                              Choose(
                                phoneNumber: widget.phoneNumber,
                                userId: bedrockUserId,
                              ),
                            ),
                          );
                        } else {
                          // 🔹 Existing user → Fetch details from Bedrock and route to home
                          final users = await BedrockClient().queryCollection(
                            'users',
                            params: {'uid': bedrockUserId},
                          );

                          if (users.isNotEmpty) {
                            final userDataWrapper = users.first;
                            final userData = userDataWrapper['data'] ?? {};
                            final userType = userData['userType'] ?? '';
                            final profileCompleted =
                                userData['profileCompleted'] == true;

                            if (!profileCompleted) {
                              Navigator.pushReplacement(
                                context,
                                slideUpRoute(
                                  Choose(
                                    phoneNumber: widget.phoneNumber,
                                    userId: bedrockUserId,
                                  ),
                                ),
                              );
                            } else {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString('userId', bedrockUserId);
                              await prefs.setString('role', userType);
                              await prefs.setBool('isLoggedIn', true);

                              // Save full profile to SharedPreferences for offline/quick access
                              await prefs.setString(
                                'barberName',
                                userData['name'] ?? '',
                              );
                              await prefs.setString(
                                'phone',
                                userData['phone'] ?? '',
                              );
                              await prefs.setString(
                                'email',
                                userData['email'] ?? '',
                              );
                              await prefs.setString(
                                'shopName',
                                userData['shopName'] ?? '',
                              );

                              if (userData['location'] != null) {
                                await prefs.setDouble(
                                  'lat',
                                  userData['location']['lat'] ?? 0.0,
                                );
                                await prefs.setDouble(
                                  'lng',
                                  userData['location']['lng'] ?? 0.0,
                                );
                              }

                              await prefs.setBool(
                                'isActive',
                                userData['isActive'] ?? false,
                              );
                              await prefs.setStringList(
                                'shopPhotos',
                                List<String>.from(userData['shopPhotos'] ?? []),
                              );

                              if (userType == 'barber') {
                                Navigator.pushReplacement(
                                  context,
                                  slideUpRoute(const BarberHome()),
                                );
                              } else if (userType == 'customer') {
                                Navigator.pushReplacement(
                                  context,
                                  slideUpRoute(const CustomerHome()),
                                );
                              }
                            }
                          } else {
                            // Handshake succeeded but no profile found (should not happen if is_new_user was false)
                            Navigator.pushReplacement(
                              context,
                              slideUpRoute(
                                Choose(
                                  phoneNumber: widget.phoneNumber,
                                  userId: bedrockUserId,
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
}
