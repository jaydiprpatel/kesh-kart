import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/otp_screen.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shimmer/shimmer.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  bool isSignUp = false;
  double _taglineOpacity = 0.0;
  TextEditingController phoneNumberController = TextEditingController();
  bool isLoading = false;
  double currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _taglineOpacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text(
          'Welcome to Kesh Kart',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Center(child: loginBlock()),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget loginBlock() {
    return Material(
      // Add Material widget to ensure proper rendering
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Image.asset('assets/images/image1.png', height: 250),

            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _taglineOpacity,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Your smooth grooming experience',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const Spacer(flex: 3),

            // Username Input
            isLoading
                ? Shimmer.fromColors(
                  baseColor: Colors.grey.shade800,
                  highlightColor: Colors.grey.shade700,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                )
                : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: TextField(
                      controller: phoneNumberController,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                      ),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 10,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/images/flag.png',
                            height: 25,
                            width: 20,
                          ),
                        ),
                        border: InputBorder.none,
                        hintText: 'Phone Number',
                      ),
                    ),
                  ),
                ),

            const SizedBox(height: 35),

            // Login Button
            Center(
              child: AnimatedGradientBorder(
                borderSize: 2,
                glowSize: 10,
                animationProgress: currentProgress, // 🟣 Controls the glow
                gradientColors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.purple.shade50,
                ],
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap:
                      isLoading
                          ? null
                          : () async {
                            final phone = phoneNumberController.text.trim();
                            String cleanedPhone = phone.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );

                            // Strip accidental leading zero ONLY if user typed 11 digits (e.g. 0XXXXXXXXXX)
                            if (cleanedPhone.length == 11 &&
                                cleanedPhone.startsWith('0')) {
                              cleanedPhone = cleanedPhone.substring(1);
                            }

                            // Ensure we have exactly 10 digits for the actual number (India standard)
                            if (cleanedPhone.length < 10) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please enter a valid 10-digit number",
                                  ),
                                ),
                              );
                              return;
                            }

                            // Ensure E.164 format with +91
                            String formattedPhone;
                            if (cleanedPhone.startsWith('91') &&
                                cleanedPhone.length > 10) {
                              formattedPhone = '+$cleanedPhone';
                            } else {
                              formattedPhone = '+91$cleanedPhone';
                            }

                            setState(() {
                              currentProgress = 1.0;
                              isLoading = true;
                            });

                            try {
                              final otpResponse = await BedrockClient()
                                  .requestOtp(formattedPhone);
                              if (!mounted) return;

                              setState(() {
                                currentProgress = 0.0;
                                isLoading = false;
                              });

                              if (otpResponse == null ||
                                  otpResponse['success'] != true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      otpResponse?['error']?.toString() ??
                                          "Unable to send OTP. Please try again.",
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.of(context).push(
                                slideUpRoute(
                                  OTPScreen(
                                    phoneNumber: formattedPhone,
                                    verificationId: 'BEDROCK_OTP',
                                    initialRemainingRequests:
                                        otpResponse['remaining_requests']
                                            as int?,
                                    resendCooldownSeconds:
                                        otpResponse['cooldown_seconds'] as int?,
                                    maxOtpRequests:
                                        otpResponse['max_requests'] as int?,
                                  ),
                                ),
                              );
                            } catch (e) {
                              setState(() {
                                currentProgress = 0.0;
                                isLoading = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: ${e.toString()}"),
                                ),
                              );
                            }
                          },

                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.grey, // grey background
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

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
