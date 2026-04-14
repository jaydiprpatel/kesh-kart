import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kesh_kart/providers/auth_provider.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:kesh_kart/otp_screen.dart';
import 'package:kesh_kart/choose.dart';
import 'package:kesh_kart/customer/home.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/backend/silent_auth_service.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/backend/config.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  bool isSignUp = false;
  double _taglineOpacity = 0.0;
  TextEditingController phoneNumberController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  // bool isLoading = false; // Moved to AuthProvider
  bool _autoVerified = false;
  bool isSilentVerifying = false;
  double currentProgress = 0.0;
  bool showPasswordField = false;
  bool isPasswordVisible = false;
  bool userExists = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _taglineOpacity = 1.0;
        });
      }
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(child: loginBlock()),
      ),
    );
  }

  Widget loginBlock() {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
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
            const SizedBox(height: 20),
            // Phone Input
            Provider.of<AuthProvider>(context).isLoading
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
                      readOnly:
                          showPasswordField, // Lock phone when entering password
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
                        suffixIcon:
                            showPasswordField
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.grey,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () => showPasswordField = false,
                                      ),
                                )
                                : null,
                        border: InputBorder.none,
                        hintText: 'Phone Number',
                      ),
                    ),
                  ),
                ),

            // Password Input (Identifier-First)
            if (showPasswordField &&
                !Provider.of<AuthProvider>(context).isLoading) ...[
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: TextField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    onSubmitted: (_) => _handleMainAction(),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 10,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock,
                        color: Color(0xFF00D189),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed:
                            () => setState(
                              () => isPasswordVisible = !isPasswordVisible,
                            ),
                      ),
                      border: InputBorder.none,
                      hintText: 'Password',
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _handleForgotPassword(),
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Color(0xFF00D189),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isLoading && !isSilentVerifying) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF00D189),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _autoVerified
                              ? "Verified! Logging you in..."
                              : showPasswordField
                              ? "Checking password..."
                              : "Checking user...",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (auth.error != null && !showPasswordField) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      auth.error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            if (isSilentVerifying)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00D189)),
                    SizedBox(height: 15),
                    Text(
                      "Secure Silent Verification in Progress...",
                      style: TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 15),
            const SizedBox(height: 20),

            // Action Button
            Center(
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return AnimatedGradientBorder(
                    borderSize: 2,
                    glowSize: 10,
                    animationProgress: currentProgress,
                    gradientColors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF00D189),
                    ],
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: auth.isLoading ? null : () => _handleMainAction(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D189),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          showPasswordField ? 'SIGN IN' : 'NEXT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMainAction() async {
    final phone = phoneNumberController.text.trim();
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedPhone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid 10-digit phone number"),
        ),
      );
      return;
    }

    final formattedPhone = '+91$cleanedPhone';

    // 1. If we are prompting for password, perform password sign in
    if (showPasswordField) {
      final pass = passwordController.text.trim();
      if (pass.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter your password")),
        );
        return;
      }

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.signInWithPhone(formattedPhone, pass);

      if (success) {
        final userId = auth.currentUser!.id;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);
        await prefs.setBool('isLoggedIn', true);

        await _routeExistingUser(userId);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Login Failed: ${auth.error}")));
      }
      return;
    }

    // 2. Otherwise, check user existence (Identifier-First)
    try {
      final result = await BaasClient.instance.sdk.auth.checkUserExists(
        formattedPhone,
      );
      final exists = result['exists'] ?? false;
      final hasPassword = result['has_password'] ?? false;

      setState(() {
        userExists = exists;
      });

      if (exists && hasPassword) {
        // Show password field for existing users with password
        setState(() => showPasswordField = true);
      } else {
        // New user or no password set -> Trigger Silent Auth / Registration
        await _startSilentAuthFlow(formattedPhone, cleanedPhone);
      }
    } catch (e) {
      // Fallback: search failed? Just try silent auth.
      await _startSilentAuthFlow(formattedPhone, cleanedPhone);
    }
  }

  Future<void> _handleForgotPassword() async {
    final phone = phoneNumberController.text.trim();
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedPhone = '+91$cleanedPhone';

    // Clear password prompt and start OTP/Silent flow for recovery
    setState(() {
      showPasswordField = false;
      passwordController.clear();
    });
    await _startSilentAuthFlow(formattedPhone, cleanedPhone);
  }

  Future<void> _startSilentAuthFlow(
    String formattedPhone,
    String cleanedPhone,
  ) async {
    Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      currentProgress = 1.0;
      isSilentVerifying = true;
    });

    try {
      // 0. If in Emulator Mode, skip silent auth and go straight to BaaS OTP
      // to ensure we use the 'verifyOtp' path which handles seeded mock codes like 123456.
      final restUrl = BaasConfig.restUrl;
      if (restUrl.contains('10.0.2.2') ||
          restUrl.contains('127.0.0.1') ||
          restUrl.contains('192.168.') ||
          restUrl.contains('localhost')) {
        debugPrint(
          "[SILENT AUTH] Local/Emulator detected. Skipping to BaaS OTP.",
        );
        await _verifyWithBaasOtp(formattedPhone, cleanedPhone);
        return;
      }

      // 1. Try Next-Gen Silent Verification First (OTP-less)
      final silentResult = await SilentAuthService.instance
          .verifyPhoneNumberSilent(formattedPhone);

      if (silentResult != null && silentResult['access_token'] != null) {
        // Silent Success / One-Tap!
        final String uid = silentResult['user_id'];
        final bool isNewUser = silentResult['is_new_user'] ?? false;

        // Securely Store Session via AuthProvider
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.updateSession(silentResult);

        setState(() {
          isSilentVerifying = false;
          _autoVerified = true;
        });

        if (isNewUser) {
          Navigator.pushReplacement(
            context,
            slideUpRoute(Choose(phoneNumber: cleanedPhone, userId: uid)),
          );
        } else {
          await _routeExistingUser(uid);
        }
        return;
      }
    } on SilentAuthException catch (e) {
      if (e.needsManualOtp) {
        setState(() {
          isSilentVerifying = false;
        });
        Navigator.of(context).push(
          slideUpRoute(
            OTPScreen(
              phoneNumber: cleanedPhone,
              verificationId: e.nonce ?? '',
              isFirebase: true,
              isSilentFallback: true,
              isSignUp: !userExists,
            ),
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint("[SILENT AUTH] Fallback due to: $e");
    } finally {
      if (mounted) setState(() => isSilentVerifying = false);
    }

    // 2. Fallback to Traditional BaaS OTP (especially for Emulator where Firebase auto-verify fails)
    try {
      await _verifyWithBaasOtp(formattedPhone, cleanedPhone);
    } catch (e) {
      if (mounted) {
        setState(() {
          currentProgress = 0.0;
        });
      }
    }
  }

  Future<void> _verifyWithBaasOtp(
    String formattedPhone,
    String cleanedPhone,
  ) async {
    try {
      debugPrint("[BAAS OTP] Requesting Traditional OTP for $formattedPhone");
      final baas = BaasClient.instance;

      await baas.sdk.auth.sendOtp(
        phone: formattedPhone,
        projectKey: baas.sdk.config.projectKey,
      );

      if (!mounted) return;

      setState(() {
        // isLoading = false; // Handled by Provider
      });

      // Navigate to OTP Screen with isFirebase: false
      Navigator.of(context).push(
        slideUpRoute(
          OTPScreen(
            phoneNumber: cleanedPhone,
            verificationId: '', // Traditional OTP doesn't use nonce here
            isFirebase: false,
            isSignUp: !userExists,
          ),
        ),
      );
    } catch (e) {
      debugPrint("[BAAS OTP] Request Failed: $e");
      rethrow;
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
      // Profile missing? Go to Choose
      Navigator.pushReplacement(
        context,
        slideUpRoute(
          Choose(
            phoneNumber: phoneNumberController.text.replaceAll(
              RegExp(r'[^0-9]'),
              '',
            ),
            userId: uid,
          ),
        ),
      );
    }
  }
}
