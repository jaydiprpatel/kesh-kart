import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/home.dart';
import 'package:kesh_kart/choose.dart';
import 'package:kesh_kart/otp_screen.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:kesh_kart/services/truecaller_login_service.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isTruecallerLoading = false;
  bool _isTruecallerUsable = false;
  final TruecallerLoginService _truecallerLoginService =
      TruecallerLoginService();
  double currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeTruecaller();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _taglineOpacity = 1.0;
      });
    });
  }

  Future<void> _initializeTruecaller() async {
    debugPrint('[Truecaller UI Diagnostic] Initializing Truecaller state...');
    final usable = await _truecallerLoginService.isUsable;
    debugPrint('[Truecaller UI Diagnostic] Truecaller usability: $usable');
    if (!mounted) return;
    setState(() => _isTruecallerUsable = usable);
  }

  Future<void> _handleTruecallerLogin() async {
    debugPrint('[Truecaller UI Diagnostic] _handleTruecallerLogin() invoked');
    if (_isTruecallerLoading || isLoading) {
      debugPrint(
        '[Truecaller UI Diagnostic] Action blocked: loading status is active (loading=$isLoading, tcLoading=$_isTruecallerLoading)',
      );
      return;
    }
    setState(() => _isTruecallerLoading = true);

    try {
      debugPrint('[Truecaller UI Diagnostic] Starting Truecaller login...');
      final truecallerResult = await _truecallerLoginService.startLogin();
      debugPrint(
        '[Truecaller UI Diagnostic] Truecaller result: $truecallerResult',
      );
      if (!mounted) return;

      if (truecallerResult == null) {
        debugPrint('[Truecaller UI Diagnostic] truecallerResult is null');
        _showMessage('Truecaller is unavailable. Please continue with OTP.');
        return;
      }

      debugPrint(
        '[Truecaller UI Diagnostic] Result state - hasToken: ${truecallerResult.hasToken}, hasAuthCode: ${truecallerResult.hasAuthorizationCode}, error: ${truecallerResult.errorMessage}',
      );

      if (!truecallerResult.hasToken &&
          !truecallerResult.hasAuthorizationCode) {
        debugPrint(
          '[Truecaller UI Diagnostic] Truecaller login failed. Surfacing error message: ${truecallerResult.errorMessage}',
        );
        _showMessage(
          truecallerResult.errorMessage ??
              'Truecaller is unavailable. Please continue with OTP.',
        );
        return;
      }

      debugPrint(
        '[Truecaller UI Diagnostic] Requesting backend authentication...',
      );
      final response = await BedrockClient().loginWithTruecaller(
        accessToken: truecallerResult.accessToken,
        authorizationCode: truecallerResult.authorizationCode,
        codeVerifier: truecallerResult.codeVerifier,
      );
      debugPrint(
        '[Truecaller UI Diagnostic] Backend response received: $response',
      );
      if (!mounted) return;

      if (response == null || response['success'] == false) {
        final errText =
            response?['error']?.toString() ??
            'Truecaller login failed. Please continue with OTP.';
        debugPrint('[Truecaller UI Diagnostic] Backend auth failed: $errText');
        _showMessage(errText);
        return;
      }

      debugPrint(
        '[Truecaller UI Diagnostic] Backend auth succeeded. Finalizing login...',
      );
      await _finishTruecallerLogin(response);
    } catch (e, stackTrace) {
      debugPrint(
        '[Truecaller UI Diagnostic] Unhandled error during Truecaller login flow: $e',
      );
      debugPrint('[Truecaller UI Diagnostic] Stack trace: $stackTrace');
      if (mounted) {
        _showMessage('Truecaller login failed. Please continue with OTP.');
      }
    } finally {
      if (mounted) setState(() => _isTruecallerLoading = false);
    }
  }

  Future<void> _finishTruecallerLogin(Map<String, dynamic> response) async {
    final userId = response['user_id']?.toString() ?? '';
    final userType = (response['user_type']?.toString() ?? '').toLowerCase();
    final phone = response['phone']?.toString() ?? '';
    if (userId.isEmpty) {
      _showMessage('Truecaller login failed. Please continue with OTP.');
      return;
    }

    final users = await BedrockClient().queryCollection(
      'users',
      params: {'uid': userId},
    );
    if (!mounted) return;
    if (users.isEmpty) {
      _goToSignupChoice(userId, phone);
      return;
    }

    final userDataWrapper = users.first;
    final userData = Map<String, dynamic>.from(userDataWrapper['data'] ?? {});
    final profileCompleted = userData['profileCompleted'] == true;
    if (!profileCompleted) {
      _goToSignupChoice(userId, phone);
      return;
    }

    await _storeProfile(userId, userType, userData);
    await NotificationService.requestPermissionAndSyncToken();
    if (!mounted) return;
    if (userType == 'barber') {
      Navigator.pushReplacement(context, slideUpRoute(const BarberHome()));
    } else if (userType == 'customer') {
      Navigator.pushReplacement(context, slideUpRoute(const CustomerHome()));
    } else {
      _goToSignupChoice(userId, phone);
    }
  }

  void _goToSignupChoice(String userId, String phone) {
    Navigator.pushReplacement(
      context,
      slideUpRoute(Choose(phoneNumber: phone, userId: userId)),
    );
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
    }

    await prefs.setBool('isActive', userData['isActive'] ?? false);
    await prefs.setStringList(
      'shopPhotos',
      List<String>.from(userData['shopPhotos'] ?? []),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _truecallerLoginService.dispose();
    phoneNumberController.dispose();
    super.dispose();
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
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: Center(child: loginBlock())),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTruecallerButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed:
            !_isTruecallerUsable || isLoading || _isTruecallerLoading
                ? null
                : _handleTruecallerLogin,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF0A66C2),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isTruecallerLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/truecaller_logo.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _isTruecallerUsable
                            ? 'Continue with Truecaller'
                            : 'Truecaller unavailable - use OTP',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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

            if (_isTruecallerUsable) ...[
              const SizedBox(height: 18),
              _buildTruecallerButton(),
            ],

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
