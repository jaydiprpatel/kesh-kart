import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kesh_kart/access/web_portal.dart';
import 'package:kesh_kart/access/role_landing.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:kesh_kart/bedrock_client.dart';
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
  final TextEditingController _reviewerPhoneController =
      TextEditingController();
  final TextEditingController _reviewerPasswordController =
      TextEditingController();
  bool isLoading = false;
  bool _isReviewerLoginLoading = false;
  bool _showReviewerLogin = false;
  bool _obscureReviewerPassword = true;
  bool _isTruecallerLoading = false;
  bool _isTruecallerUsable = false;
  final TruecallerLoginService _truecallerLoginService =
      TruecallerLoginService();
  double currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Truecaller is intentionally paused. Phone OTP is the only active
    // customer sign-in method until this integration is revisited.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _taglineOpacity = 1.0;
      });
    });
  }

  // ignore: unused_element
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
      await _finishAuthenticatedLogin(response);
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

  Future<void> _finishAuthenticatedLogin(Map<String, dynamic> response) async {
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
    if (userType == 'barber' && !kIsWeb) {
      await NotificationService.requestPermissionAndSyncToken();
    }
    if (!mounted) return;
    if (userType == 'barber') {
      Navigator.pushReplacement(context, slideUpRoute(RoleLanding.barber()));
    } else if (userType == 'customer') {
      // Android is intentionally barber-only. Customer accounts never enter
      // customer discovery or booking screens from this binary.
      Navigator.pushReplacement(context, slideUpRoute(RoleLanding.customer()));
    } else {
      _goToSignupChoice(userId, phone);
    }
  }

  Future<void> _handleReviewerLogin() async {
    if (_isReviewerLoginLoading || isLoading) return;

    // Reviewer credentials are commonly pasted from a verification form.
    // Remove whitespace and phone separators before sending the request.
    final phone = _reviewerPhoneController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final password = _reviewerPasswordController.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      _showMessage('Enter the reviewer mobile number and password.');
      return;
    }
    if (phone.length != 10) {
      _showMessage('Enter the 10-digit reviewer mobile number.');
      return;
    }

    setState(() => _isReviewerLoginLoading = true);
    try {
      final response = await BedrockClient().loginAsRazorpayReviewer(
        phone: phone,
        password: password,
      );
      if (!mounted) return;
      if (response == null || response['success'] != true) {
        _showMessage('Reviewer sign-in could not be completed.');
        return;
      }
      await _finishAuthenticatedLogin(response);
    } finally {
      if (mounted) setState(() => _isReviewerLoginLoading = false);
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
    _reviewerPhoneController.dispose();
    _reviewerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text(
          'Welcome to Kesh Kart',
          style: TextStyle(
            color: Color(0xFF091426),
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
              child: IntrinsicHeight(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: loginBlock(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAuthDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    );
  }

  // ignore: unused_element
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
          disabledForegroundColor: Colors.white54,
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
                    ClipOval(
                      child: Image.asset(
                        'assets/images/truecaller_logo.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
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
                    color: Colors.black54,
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
                  baseColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                )
                : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
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

            if (kIsWeb && KeshKartWebPortal.isBarber) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed:
                    _isReviewerLoginLoading
                        ? null
                        : () => setState(
                          () => _showReviewerLogin = !_showReviewerLogin,
                        ),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Razorpay reviewer sign in'),
              ),
              if (_showReviewerLogin) ...[
                const SizedBox(height: 8),
                _buildReviewerLoginPanel(),
              ],
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
                      color: Color(0xFF091426),
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

  Widget _buildReviewerLoginPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF091426).withValues(alpha: .16),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Razorpay verification access',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use the dedicated test mobile number and password supplied for review.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reviewerPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Test mobile number',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reviewerPasswordController,
            obscureText: _obscureReviewerPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed:
                    () => setState(
                      () =>
                          _obscureReviewerPassword = !_obscureReviewerPassword,
                    ),
                icon: Icon(
                  _obscureReviewerPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            onSubmitted: (_) => _handleReviewerLogin(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isReviewerLoginLoading ? null : _handleReviewerLogin,
              child:
                  _isReviewerLoginLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Open reviewer account'),
            ),
          ),
        ],
      ),
    );
  }
}
