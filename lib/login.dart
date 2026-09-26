import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kesh_kart/access/web_portal.dart';
import 'package:kesh_kart/access/role_landing.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/choose.dart';
import 'package:kesh_kart/otp_screen.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:kesh_kart/services/truecaller_login_service.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController _reviewerPhoneController =
      TextEditingController();
  final TextEditingController _reviewerPasswordController =
      TextEditingController();

  bool isLoading = false;
  bool _isReviewerLoginLoading = false;
  bool _obscureReviewerPassword = true;
  final TruecallerLoginService _truecallerLoginService =
      TruecallerLoginService();

  @override
  void dispose() {
    _truecallerLoginService.dispose();
    phoneNumberController.dispose();
    _reviewerPhoneController.dispose();
    _reviewerPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handlePhoneLogin() async {
    if (isLoading) return;

    final phone = phoneNumberController.text.trim();
    String cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Strip accidental leading zero ONLY if user typed 11 digits (e.g. 0XXXXXXXXXX)
    if (cleanedPhone.length == 11 && cleanedPhone.startsWith('0')) {
      cleanedPhone = cleanedPhone.substring(1);
    }

    // Ensure we have exactly 10 digits for India standard
    if (cleanedPhone.length < 10) {
      _showMessage("Please enter a valid 10-digit number");
      return;
    }

    // Ensure E.164 format with +91
    String formattedPhone;
    if (cleanedPhone.startsWith('91') && cleanedPhone.length > 10) {
      formattedPhone = '+$cleanedPhone';
    } else {
      formattedPhone = '+91$cleanedPhone';
    }

    setState(() => isLoading = true);

    try {
      final otpResponse = await BedrockClient().requestOtp(formattedPhone);
      if (!mounted) return;

      setState(() => isLoading = false);

      if (otpResponse == null || otpResponse['success'] != true) {
        _showMessage(
          otpResponse?['error']?.toString() ??
              "Unable to send OTP. Please try again.",
        );
        return;
      }

      Navigator.of(context).push(
        slideUpRoute(
          OTPScreen(
            phoneNumber: formattedPhone,
            verificationId: 'BEDROCK_OTP',
            initialRemainingRequests: otpResponse['remaining_requests'] as int?,
            resendCooldownSeconds: otpResponse['cooldown_seconds'] as int?,
            maxOtpRequests: otpResponse['max_requests'] as int?,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showMessage("Error: ${e.toString()}");
    }
  }

  Future<void> _finishAuthenticatedLogin(Map<String, dynamic> response) async {
    final userId = response['user_id']?.toString() ?? '';
    final userType = (response['user_type']?.toString() ?? '').toLowerCase();
    final phone = response['phone']?.toString() ?? '';
    if (userId.isEmpty) {
      _showMessage('Sign in could not be completed. Please try again.');
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
      Navigator.pushReplacement(context, slideUpRoute(RoleLanding.customer()));
    } else {
      _goToSignupChoice(userId, phone);
    }
  }

  Future<void> _handleReviewerLogin() async {
    if (_isReviewerLoginLoading || isLoading) return;

    final suppliedDigits = _reviewerPhoneController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final phone =
        suppliedDigits.length == 12 && suppliedDigits.startsWith('91')
            ? suppliedDigits.substring(2)
            : suppliedDigits;
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0F13),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  width: double.infinity,
                  height: screenHeight,
                  child: Stack(
                    children: [
                      // 1. Barbershop Hero Image with Seamless Dark Fade (Upper 48%)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: screenHeight * 0.50,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/login_bg.jpg',
                              fit: BoxFit.cover,
                              alignment: const Alignment(0.4, -0.2),
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFF14171E),
                                );
                              },
                            ),
                            // Top dark gradient for logo readability
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.0, 0.40],
                                  colors: [
                                    Color(0xE60D0F13),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Left dark gradient for headline contrast
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  stops: [0.0, 0.50, 0.90],
                                  colors: [
                                    Color(0xD90D0F13),
                                    Color(0x770D0F13),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Bottom smooth fade into background
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.25, 0.70, 1.0],
                                  colors: [
                                    Colors.transparent,
                                    Color(0xB30D0F13),
                                    Color(0xFF0D0F13),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Bottom Decorative Ribbon
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _BottomDecorativeRibbon(),
                      ),

                      // 3. Foreground Content Column (Proportionally Spaced to fit 1 page)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: topPadding > 0 ? topPadding + 4 : 14,
                            ),

                            // Top Gold Kesh Kart Logo
                            const _KeshKartLogoHeader(),

                            const SizedBox(height: 12),

                            // Left-aligned Welcome Headline
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome to',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Popins',
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback:
                                      (bounds) => const LinearGradient(
                                        colors: [
                                          Color(0xFFFFF0D0),
                                          Color(0xFFE8BD70),
                                          Color(0xFFBF8832),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                  child: const Text(
                                    'Kesh Kart',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Popins',
                                      height: 1.1,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Your smooth grooming experience',
                                  style: TextStyle(
                                    color: Color(0xFFC7CDD8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'Popins',
                                  ),
                                ),
                              ],
                            ),

                            // Proportional spacer between headline and features card
                            const Spacer(flex: 3),

                            // Feature Highlights Card
                            _buildFeaturesCard(),

                            const SizedBox(height: 14),

                            // Phone Number Input Box
                            _buildPhoneInputBox(),

                            const SizedBox(height: 16),

                            // Circular Glowing Arrow Button
                            Center(child: _buildSubmitButton()),

                            // Proportional spacer above bottom wave
                            const Spacer(flex: 2),

                            // The dedicated reviewer account is only accepted
                            // server-side for one configured phone number. It
                            // must be reachable in the Android barber build as
                            // well as the barber web portal for Play review.
                            if (!kIsWeb || KeshKartWebPortal.isBarber)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    onTap:
                                        () => _showReviewerLoginDialog(context),
                                    child: const Text(
                                      'Reviewer sign in',
                                      style: TextStyle(
                                        color: Color(0xFFE8BD70),
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Space reserved for the bottom wave text
                            const SizedBox(height: 70),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showReviewerLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildReviewerLoginPanel(),
          ),
    );
  }

  Widget _buildFeaturesCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF15181E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _FeatureItem(
              icon: Icons.calendar_month_outlined,
              label: 'Book\nAppointment',
            ),
          ),
          Expanded(
            child: _FeatureItem(
              icon: Icons.content_cut_rounded,
              label: 'Professional\nStylists',
            ),
          ),
          Expanded(
            child: _FeatureItem(
              icon: Icons.verified_user_outlined,
              label: 'Hygienic\n& Safe',
            ),
          ),
          Expanded(
            child: _FeatureItem(
              icon: Icons.star_rounded,
              label: 'Great\nExperience',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInputBox() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8BD70), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8BD70).withValues(alpha: 0.22),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 14),
          Image.asset(
            'assets/images/flag.png',
            height: 20,
            width: 26,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text('🇮🇳', style: TextStyle(fontSize: 20));
            },
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280),
            size: 20,
          ),
          Container(
            height: 24,
            width: 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFFD1D5DB),
          ),
          Expanded(
            child: TextField(
              controller: phoneNumberController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'Popins',
                letterSpacing: 0.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: 'Phone Number',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Popins',
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                isDense: true,
              ),
              onSubmitted: (_) => _handlePhoneLogin(),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF282D38), Color(0xFF11141A)],
          center: Alignment(-0.2, -0.3),
        ),
        border: Border.all(color: const Color(0xFFE8BD70), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8BD70).withValues(alpha: 0.40),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(29),
          onTap: isLoading ? null : _handlePhoneLogin,
          child: Center(
            child:
                isLoading
                    ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFE8BD70),
                        ),
                      ),
                    )
                    : const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewerLoginPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15181E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8BD70).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Razorpay verification access',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use the dedicated test mobile number and password supplied for review.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reviewerPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 12,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Test mobile number',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reviewerPasswordController,
            obscureText: _obscureReviewerPassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.white70),
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
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
                  color: Colors.white70,
                ),
              ),
            ),
            onSubmitted: (_) => _handleReviewerLogin(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8BD70),
                foregroundColor: const Color(0xFF0D0F13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isReviewerLoginLoading ? null : _handleReviewerLogin,
              child:
                  _isReviewerLoginLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0D0F13),
                          ),
                        ),
                      )
                      : const Text(
                        'Open reviewer account',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Component: Top Logo Header
// -------------------------------------------------------------
class _KeshKartLogoHeader extends StatelessWidget {
  const _KeshKartLogoHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Golden Scissors & Comb Emblem
        CustomPaint(
          size: const Size(36, 32),
          painter: _ScissorsCombEmblemPainter(),
        ),
        const SizedBox(height: 4),
        // KESH KART Brand Name
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFFF0D0),
                  Color(0xFFE8BD70),
                  Color(0xFFBF8832),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
          child: const Text(
            'KESH KART',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.0,
              fontFamily: 'Popins',
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Tagline
        const Text(
          'LOOK GOOD     FEEL BETTER',
          style: TextStyle(
            color: Color(0xFFE8BD70),
            fontSize: 8.0,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 34,
          height: 1.5,
          decoration: BoxDecoration(
            color: const Color(0xFFE8BD70),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Component: Individual Feature Pill
// -------------------------------------------------------------
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF222631),
            border: Border.all(
              color: const Color(0xFFE8BD70).withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Icon(icon, color: const Color(0xFFE8BD70), size: 18),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDDE1E8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'Popins',
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Component: Bottom Decorative Flowing Ribbon
// -------------------------------------------------------------
class _BottomDecorativeRibbon extends StatelessWidget {
  const _BottomDecorativeRibbon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      width: double.infinity,
      child: Stack(
        children: [
          // Wave Graphic Painter
          Positioned.fill(child: CustomPaint(painter: _BottomWavePainter())),
          // Watermark on Bottom Right
          Positioned(
            right: 14,
            bottom: 2,
            child: Opacity(
              opacity: 0.16,
              child: Transform.rotate(
                angle: -0.35,
                child: CustomPaint(
                  size: const Size(70, 65),
                  painter: _BarberWatermarkPainter(),
                ),
              ),
            ),
          ),
          // "Grooming Made Simple" Text on Bottom Left
          Positioned(
            left: 20,
            bottom: 12,
            child: Transform.rotate(
              angle: -0.14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Grooming',
                    style: TextStyle(
                      color: Color(0xFFC7CDD8),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Text(
                    'Made Simple',
                    style: TextStyle(
                      color: Color(0xFFC7CDD8),
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.6,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 44,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8BD70),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Painter: Scissors & Comb Emblem for Logo
// -------------------------------------------------------------
class _ScissorsCombEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint =
        Paint()
          ..color = const Color(0xFFE8BD70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

    final fillGold =
        Paint()
          ..color = const Color(0xFFE8BD70)
          ..style = PaintingStyle.fill;

    // Comb on the right
    final combLeft = size.width * 0.65;
    final combRight = size.width * 0.76;
    final combTop = size.height * 0.12;
    final combBottom = size.height * 0.88;

    // Comb spine
    canvas.drawLine(
      Offset(combRight, combTop),
      Offset(combRight, combBottom),
      Paint()
        ..color = const Color(0xFFE8BD70)
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );

    // Comb teeth
    const teethCount = 7;
    for (int i = 0; i < teethCount; i++) {
      final y = combTop + (combBottom - combTop) * (i / (teethCount - 1));
      canvas.drawLine(
        Offset(combLeft, y),
        Offset(combRight, y),
        Paint()
          ..color = const Color(0xFFE8BD70)
          ..strokeWidth = 1.4,
      );
    }

    // Scissors on the left
    // Left finger loop
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.24, size.height * 0.78),
        width: 10,
        height: 14,
      ),
      goldPaint,
    );

    // Right finger loop
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.44, size.height * 0.78),
        width: 10,
        height: 14,
      ),
      goldPaint,
    );

    // Pivot screw
    canvas.drawCircle(
      Offset(size.width * 0.34, size.height * 0.52),
      2.0,
      fillGold,
    );

    // Blade 1
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.70),
      Offset(size.width * 0.45, size.height * 0.14),
      goldPaint,
    );

    // Blade 2
    canvas.drawLine(
      Offset(size.width * 0.43, size.height * 0.70),
      Offset(size.width * 0.20, size.height * 0.14),
      goldPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// Painter: Sweeping Bottom Wave with Golden Accent Border
// -------------------------------------------------------------
class _BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Lower Dark Body
    final darkPath = Path();
    darkPath.moveTo(0, size.height * 0.32);
    darkPath.cubicTo(
      size.width * 0.38,
      size.height * 0.72,
      size.width * 0.70,
      size.height * 0.15,
      size.width,
      size.height * 0.42,
    );
    darkPath.lineTo(size.width, size.height);
    darkPath.lineTo(0, size.height);
    darkPath.close();

    final darkPaint = Paint()..color = const Color(0xFF090B0F);
    canvas.drawPath(darkPath, darkPaint);

    // 2. Golden Contour Stroke Ribbon
    final goldStrokePath = Path();
    goldStrokePath.moveTo(0, size.height * 0.32);
    goldStrokePath.cubicTo(
      size.width * 0.38,
      size.height * 0.72,
      size.width * 0.70,
      size.height * 0.15,
      size.width,
      size.height * 0.42,
    );

    final goldGradient = const LinearGradient(
      colors: [
        Color(0xFF8A6520),
        Color(0xFFFFECBC),
        Color(0xFFE8BD70),
        Color(0xFFA87724),
      ],
      stops: [0.0, 0.45, 0.75, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final goldStrokePaint =
        Paint()
          ..shader = goldGradient
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;

    canvas.drawPath(goldStrokePath, goldStrokePaint);

    // Secondary subtle lower gold highlight wave
    final subGoldPath = Path();
    subGoldPath.moveTo(0, size.height * 0.46);
    subGoldPath.cubicTo(
      size.width * 0.42,
      size.height * 0.85,
      size.width * 0.75,
      size.height * 0.32,
      size.width,
      size.height * 0.55,
    );

    final subGoldPaint =
        Paint()
          ..shader = goldGradient
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    canvas.drawPath(subGoldPath, subGoldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// Painter: Translucent Barber Comb & Scissors Watermark
// -------------------------------------------------------------
class _BarberWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint =
        Paint()
          ..color = const Color(0xFFE8BD70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;

    // Comb outline
    final spineX = size.width * 0.82;
    canvas.drawLine(
      Offset(spineX, 10),
      Offset(spineX, size.height - 10),
      Paint()
        ..color = const Color(0xFFE8BD70)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round,
    );

    for (double y = 16; y < size.height - 12; y += 12) {
      canvas.drawLine(
        Offset(size.width * 0.52, y),
        Offset(spineX, y),
        Paint()
          ..color = const Color(0xFFE8BD70)
          ..strokeWidth = 2.4,
      );
    }

    // Scissors outline
    canvas.drawCircle(
      Offset(size.width * 0.24, size.height * 0.78),
      14,
      goldPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.82),
      14,
      goldPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.24, size.height * 0.68),
      Offset(size.width * 0.48, 12),
      goldPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.48, size.height * 0.70),
      Offset(size.width * 0.16, 16),
      goldPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
