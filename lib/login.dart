import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:kesh_kart/otp_screen.dart';
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
  double currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(child: loginBlock()),
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

            const SizedBox(height: 15),
            const SizedBox(height: 20),

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
                            final cleanedPhone = phone.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );
                            final formattedPhone = '+91$cleanedPhone';

                            if (phone.isEmpty || phone.length < 10) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please enter a valid phone number",
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              currentProgress = 1.0;
                              isLoading = true;
                            });

                            try {
                              // 🔍 Check if user exists in Firestore
                              final snapshot =
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .where('phone', isEqualTo: formattedPhone)
                                      .limit(1)
                                      .get();

                              final isSignUp = snapshot.docs.isEmpty;
                              final userId =
                                  isSignUp ? null : snapshot.docs.first.id;
                              final userName =
                                  isSignUp
                                      ? ''
                                      : snapshot.docs.first.data()['name'] ??
                                          '';

                              debugPrint(
                                "📱 Firestore check → isSignUp: $isSignUp",
                              );

                              if (!isSignUp) {
                                final data = snapshot.docs.first.data();

                                final prefs =
                                    await SharedPreferences.getInstance();

                                await prefs.setString(
                                  'userId',
                                  snapshot.docs.first.id,
                                );
                                await prefs.setString(
                                  'barberName',
                                  data['name'] ?? '',
                                );
                                await prefs.setString(
                                  'phone',
                                  data['phone'] ?? '',
                                );
                                await prefs.setString(
                                  'email',
                                  data['email'] ?? '',
                                );
                                await prefs.setString(
                                  'shopName',
                                  data['shopName'] ?? '',
                                );
                                await prefs.setStringList(
                                  'shopPhotos',
                                  List<String>.from(data['shopPhotos'] ?? []),
                                );
                                await prefs.setDouble(
                                  'lat',
                                  data['location']['lat'],
                                );
                                await prefs.setDouble(
                                  'lng',
                                  data['location']['lng'],
                                );
                                await prefs.setBool(
                                  'isActive',
                                  data['isActive'] ?? false,
                                );
                                await prefs.setString(
                                  'userType',
                                  data['userType'] ?? 'barber',
                                );
                                await prefs.setBool('isLoggedIn', true);
                              }

                              await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: formattedPhone,
                                timeout: const Duration(seconds: 60),
                                verificationCompleted:
                                    (PhoneAuthCredential credential) {},
                                verificationFailed: (FirebaseAuthException e) {
                                  setState(() {
                                    currentProgress = 0.0;
                                    isLoading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Verification failed: ${e.message}",
                                      ),
                                    ),
                                  );
                                },
                                codeSent: (
                                  String verificationId,
                                  int? resendToken,
                                ) {
                                  setState(() {
                                    currentProgress = 0.0;
                                    isLoading = false;
                                  });

                                  Navigator.of(context).push(
                                    slideUpRoute(
                                      OTPScreen(
                                        phoneNumber: phone,
                                        isSignUp: isSignUp,
                                        userName: userName,
                                        userId: userId,
                                        verificationId: verificationId,
                                      ),
                                    ),
                                  );
                                },
                                codeAutoRetrievalTimeout:
                                    (String verificationId) {},
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

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
