import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/customer/home.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  final String phoneNumber;
  final String userId;
  final String role;

  const RegisterScreen({
    super.key,
    required this.role,
    required this.phoneNumber,
    required this.userId,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _shopNumberController = TextEditingController();
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  bool _isFetchingLocation = false;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  double _iconOpacity = 0.0;
  double _taglineOpacity = 0.0;
  Timer? _timer;
  int _secondsRemaining = 30;
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  final List<String> _shopPhotos = [];
  double? _latitude;
  double? _longitude;
  DateTime? _locationTimestamp;
  bool? _isMocked;

  bool _isSubmitting = false;

  final List<XFile> _pendingPhotoFiles = [];

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _iconOpacity = 1.0);
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _taglineOpacity = 1.0);
    });

    _startResendTimer();

    _pinCodeController.addListener(() {
      final pin = _pinCodeController.text.trim();
      if (pin.length == 6) {
        _fetchCityStateFromPincode(pin);
      }
    });

    // 🔐 Clean previous uploads if profile is not completed
    if (widget.role.trim().toLowerCase() == 'barber') {
      _checkAndCleanPreviousUploads();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _seedData() {
    setState(() {
      _nameController.text = "Test User";
      _emailController.text =
          "test${DateTime.now().millisecondsSinceEpoch}@baas.com";
      _passwordController.text = "123456";
      _confirmPasswordController.text = "123456";

      if (widget.role.trim().toLowerCase() == 'barber') {
        _shopNameController.text = "Kesh Kart Style";
        _shopNumberController.text = "A-101";
        _buildingNameController.text = "Galaxy Heights";
        _localityController.text = "MG Road";
        _landmarkController.text = "Near City Center";
        _pinCodeController.text = "388620";
        _fetchCityStateFromPincode("388620");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: kDebugMode
          ? FloatingActionButton(
            onPressed: _seedData,
            backgroundColor: const Color(0xFF00D189),
            child: const Icon(Icons.flash_on, color: Colors.white),
          )
          : null,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Join Kesh-Kart',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // 🔹 Sign Up Illustration
              AnimatedOpacity(
                opacity: _iconOpacity,
                duration: const Duration(milliseconds: 600),
                child: Image.asset('assets/images/SignUp.png', height: 200),
              ),

              const SizedBox(height: 10),

              // 🔹 Tagline
              AnimatedOpacity(
                opacity: _taglineOpacity,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Currently live in Vadodara.\nRegistration open for all cities.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 Fields (form or shimmer)
              if (widget.role.trim().toLowerCase() == 'customer')
                _isSubmitting
                    ? _buildCustomerFormShimmer()
                    : _buildCustomerFormFields()
              else
                _isSubmitting
                    ? _buildBarberFormShimmer()
                    : _buildBarberWizard(),

              const SizedBox(height: 40),

              // 🔹 Submit button (always visible)
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
    Iterable<String>? autofillHints,
    VoidCallback? toggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white10,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        suffixIcon:
            toggleObscure != null
                ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                  ),
                  onPressed: toggleObscure,
                )
                : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _startResendTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel(); // stop updating after screen is gone
        return;
      }

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }



  Widget _buildPhotoUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload shop photos (max 5):',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:
                _pendingPhotoFiles.length +
                (_pendingPhotoFiles.length < 5 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index < _pendingPhotoFiles.length) {
                final file = _pendingPhotoFiles[index];
                return GestureDetector(
                  onTap: () {
                    setState(() => _pendingPhotoFiles.remove(file));
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        kIsWeb
                            ? Image.network(
                              file.path,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                            : Image.file(
                              File(file.path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                  ),
                );
              } else {
                // Add photo button
                return GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      setState(() {
                        _pendingPhotoFiles.add(image);
                      });
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.white54),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerFormShimmer() {
    return Column(
      children: List.generate(4, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade900,
            highlightColor: Colors.grey.shade800,
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSubmitButton() {
    final bool isBarber = widget.role.trim().toLowerCase() == 'barber';
    final bool isLastStep = !isBarber || _currentStep == _totalSteps - 1;

    return Column(
      children: [
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
              onTap: _isSubmitting ? null : _handleSubmit,
              child: Opacity(
                opacity: _isSubmitting ? 0.5 : 1.0,
                child: Container(
                  width: isLastStep ? 200 : 70,
                  height: 60,
                  padding: isLastStep ? const EdgeInsets.symmetric(horizontal: 20) : null,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLastStep) ...[
                        Text(
                          isBarber ? "FINISH REGISTRATION" : "COMPLETE SIGNUP",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      const Icon(
                        CupertinoIcons.arrow_right,
                        color: Colors.white,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isBarber && _currentStep > 0 && !_isSubmitting)
          TextButton(
            onPressed: () => setState(() => _currentStep--),
            child: const Text(
              "Go Back",
              style: TextStyle(color: Colors.white54),
            ),
          ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    final role = widget.role.trim().toLowerCase();
    final uid = widget.userId;
    final pincode = _pinCodeController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();

    // 1. Basic Validation
    if (role == 'customer') {
      if (_nameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text != _passwordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields correctly')),
        );
        return;
      }
    } else {
      // BARBER WIZARD LOGIC
      if (_currentStep == 0) {
        if (_nameController.text.trim().isEmpty ||
            _emailController.text.trim().isEmpty ||
            _passwordController.text.isEmpty ||
            _shopNameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill your identity details')),
          );
          return;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match')),
          );
          return;
        }
        setState(() => _currentStep = 1);
        return;
      } else if (_currentStep == 1) {
        if (_pinCodeController.text.trim().isEmpty ||
            _cityController.text.trim().isEmpty ||
            _stateController.text.trim().isEmpty ||
            _shopNumberController.text.trim().isEmpty ||
            _buildingNameController.text.trim().isEmpty ||
            _localityController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete shop address')),
          );
          return;
        }
        setState(() => _currentStep = 2);
        return;
      } else {
        // Final Step Validation
        if (_latitude == null || _longitude == null || _pendingPhotoFiles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS and Photos are mandatory')),
          );
          return;
        }
      }
    }

    if (pincode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN Code is required for local entry.')),
      );
      return;
    }

    // OPTIONAL: Invite code is no longer mandatory
    // if (role == 'customer' && inviteCode.isEmpty) { ... }

    // Mandatory GPS for Customers
    if (role == 'customer' && (_latitude == null || _longitude == null)) {
      setState(() => _isSubmitting = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching your location...')),
      );

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() => _isSubmitting = false);
          _showLocationDeniedDialog();
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationTimestamp = position.timestamp;
        _isMocked = position.isMocked;
      } catch (e) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not fetch location: $e')));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Validating...")));

    try {
      // 2. Validate Pincode and City Lock (Backend Authority)
      final pincodeSnap =
          await BaasClient.collection(
            'pincodes',
          ).where('id', isEqualTo: pincode).limit(1).get();

      String cityId = 'VADODARA_FALLBACK';
      String cityName = 'Other City';

      if (pincodeSnap.docs.isNotEmpty &&
          pincodeSnap.docs.first.data['isActive'] == true) {
        cityId = pincodeSnap.docs.first.data['cityId'];

        final citySnap =
            await BaasClient.collection(
              'cities',
            ).where('id', isEqualTo: cityId).limit(1).get();

        if (citySnap.docs.isNotEmpty &&
            citySnap.docs.first.data['isActive'] == true) {
          cityName = citySnap.docs.first.data['name'];
        }
      } else {
        debugPrint("Location fallback triggered for pincode: $pincode");
      }

      // 3. Validate Invite (ATOMIC TRANSACTION) - ONLY FOR CUSTOMERS
      Map<String, dynamic>? inviteMeta;

      if (role == 'customer' && inviteCode.isNotEmpty) {
        // First, find the document to get its actual UUID
        final inviteLookup =
            await BaasClient.collection(
              'invites',
            ).where('id', isEqualTo: inviteCode).limit(1).get();

        if (inviteLookup.docs.isEmpty) {
          throw Exception('Invalid invite code.');
        }

        final inviteUuid = inviteLookup.docs.first.id;

        inviteMeta = await BaasClient.instance.sdk.runTransaction((tx) async {
          final inviteRef = BaasClient.instance.sdk
              .collection('invites')
              .doc(inviteUuid);
          final inviteDoc = await tx.get(inviteRef);
          final inviteData = inviteDoc.data;

          if (inviteData['isActive'] != true) {
            throw Exception('This invite code is no longer active.');
          }

          if (inviteData['role'] != role) {
            throw Exception('This invite is not valid for ${role}s.');
          }

          if (inviteData['cityId'] != cityId) {
            throw Exception('This invite is only valid for $cityName.');
          }

          final expiry = DateTime.parse(inviteData['expiryDate']);
          if (DateTime.now().isAfter(expiry)) {
            throw Exception('This invite has expired.');
          }

          final usageLimit = inviteData['usageLimit'] ?? 0;
          final usageCount = inviteData['usageCount'] ?? 0;
          if (usageCount >= usageLimit) {
            throw Exception('Invite usage limit reached.');
          }

          final todayStr = DateTime.now().toIso8601String().split('T')[0];
          final dailyUsageMap = Map<String, dynamic>.from(
            inviteData['dailyUsage'] ?? {},
          );
          final todayUsage = dailyUsageMap[todayStr] ?? 0;
          if (todayUsage >= 5) {
            throw Exception('Daily invite limit reached. Please try tomorrow.');
          }

          // Increment and Update
          dailyUsageMap[todayStr] = todayUsage + 1;
          tx.update(inviteRef, {
            'usageCount': usageCount + 1,
            'dailyUsage': dailyUsageMap,
          });

          return {
            'code': inviteCode,
            'uuid': inviteUuid,
            'ownerId': inviteData['ownerId'],
            'cityId': cityId,
            'role': role,
          };
        });
      }

      // 4. Create User Profile
      final email = _emailController.text.trim();
      List<String> uploadedUrls = [];

      for (XFile file in _pendingPhotoFiles) {
        final fileName = path.basename(file.path);
        final ref = BaasClient.instance.sdk.storage.ref(
          'shop_photos/${DateTime.now().millisecondsSinceEpoch}_$fileName',
        );
        final bytes = await file.readAsBytes();
        final storedFile = await ref.putBytes(bytes, contentType: 'image/jpeg');
        uploadedUrls.add(storedFile.downloadUrl);
      }

      final Map<String, dynamic> userData = {
        'uid': uid,
        'phone': '+91${widget.phoneNumber}',
        'name': _nameController.text.trim(),
        'email': email,
        'userType': role,
        'hasPassword': true,
        'profileCompleted': true,
        'createdAt': DateTime.now().toIso8601String(),
        'pincode': pincode,
        'cityId': cityId,
        'invitedBy': inviteMeta?['ownerId'] ?? 'ADMIN',
        'inviteMeta':
            inviteMeta, // Historical truth snapshot (can be null for barbers)
      };

      if (role == 'barber') {
        final fullAddress = [
          _shopNumberController.text.trim(),
          _buildingNameController.text.trim(),
          _localityController.text.trim(),
          _landmarkController.text.trim(),
          _cityController.text.trim(),
          _stateController.text.trim(),
          pincode,
        ].where((part) => part.isNotEmpty).join(', ');

        userData.addAll({
          'shopName': _shopNameController.text.trim(),
          'shopAddress': fullAddress,
          'location': {'lat': _latitude, 'lng': _longitude},
          'shopPhotos': uploadedUrls,
          // Barber Authenticity & Referral fields
          'verificationStatus': 'unverified',
          'processedReferralEvents': [],
          'successfulBarberInvites': 0,
          'highestRewardTierUnlocked': 0,
          'currentSubscriptionPrice': 199, // Launch pricing
          'discountExpiry': null,
          'freeSubscriptionGranted': false,
        });
      }

      await BaasClient.instance.sdk.auth.completeProfile(
        email: email,
        password: _passwordController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        locationTimestamp: _locationTimestamp,
        isMocked: _isMocked,
      );

      await BaasClient.collection('users').doc(uid).set(userData);

      // FCM sync
      try {
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await BaasClient.instance.updateFcmToken(fcmToken);
        }
      } catch (_) {}

      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', uid);
      await prefs.setString('role', role);
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userType', role);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration Successful! Redirecting...'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      if (role == 'barber') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BarberHome()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHome()),
        );
      }
    } catch (e) {
      debugPrint("Registration Error: $e");
      String errorMsg = e.toString().replaceAll('Exception: ', '');

      if (mounted) {
        setState(() => _isSubmitting = false);

        if (errorMsg.contains('OUT_OF_BOUNDARY')) {
          _showBoundaryRestrictionDialog();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      }
    }
  }

  void _showLocationDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Location Required',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'To ensure we can serve you better, location permission is mandatory for signup. We currently operate only in Vadodara.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF00D189)),
                ),
              ),
            ],
          ),
    );
  }

  void _showBoundaryRestrictionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text(
              'Outside Vadodara',
              style: TextStyle(color: Colors.white),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kesh-Kart is currently available exclusively within Vadodara city limits.',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 10),
                Text(
                  'Would you like to join our waitlist? We\'ll notify you when we launch in your area!',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'MAYBE LATER',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D189),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _joinWaitlist();
                },
                child: const Text(
                  'JOIN WAITLIST',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _joinWaitlist() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill name and email to join waitlist'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await BaasClient.collection('waitlist').add({
        'name': name,
        'email': email,
        'phone': '+91${widget.phoneNumber}',
        'latitude': _latitude,
        'longitude': _longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'Waitlist Joined!',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Check your email for updates. We can\'t wait to bring Kesh-Kart to you!',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'GREAT',
                    style: TextStyle(color: Color(0xFF00D189)),
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Waitlist error: $e')));
    }
  }

  Widget _buildBarberWizard() {
    return Column(
      children: [
        _buildProgressIndicator(),
        const SizedBox(height: 30),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: KeyedSubtree(
            key: ValueKey(_currentStep),
            child: _getStepWidget(),
          ),
        ),
      ],
    );
  }

  Widget _getStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildBarberStep1();
      case 1:
        return _buildBarberStep2();
      case 2:
        return _buildBarberStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(_totalSteps, (index) {
        bool isCompleted = index < _currentStep;
        bool isCurrent = index == _currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isCompleted || isCurrent
                  ? const Color(0xFF00D189)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(2),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00D189).withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBarberStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Personal & Shop Identity",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Let's start with who you are and your shop's name.",
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 25),
        _buildTextField(controller: _shopNameController, hint: 'Shop Name'),
        const SizedBox(height: 20),
        _buildTextField(controller: _nameController, hint: 'Full Name'),
        const SizedBox(height: 20),
        _buildTextField(controller: _emailController, hint: 'Email ID'),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController,
          hint: 'Password',
          obscureText: _obscurePassword,
          toggleObscure:
              () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _confirmPasswordController,
          hint: 'Confirm Password',
          obscureText: _obscureConfirm,
          toggleObscure:
              () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ],
    );
  }

  Widget _buildBarberStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Shop Location Details",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Provide the physical address of your shop.",
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 25),
        _buildTextField(
          controller: _pinCodeController,
          hint: 'PIN Code',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(controller: _cityController, hint: 'City'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  _buildTextField(controller: _stateController, hint: 'State'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTextField(controller: _shopNumberController, hint: 'Shop/Plot #'),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _buildingNameController,
          hint: 'Building/Complex Name',
        ),
        const SizedBox(height: 20),
        _buildTextField(controller: _localityController, hint: 'Locality/Area'),
        const SizedBox(height: 20),
        _buildTextField(controller: _landmarkController, hint: 'Landmark'),
      ],
    );
  }

  Widget _buildBarberStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Visuals & GPS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Final step! Capture your location and add shop photos.",
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 25),
        _buildEnhancedLocationPicker(),
        const SizedBox(height: 30),
        _buildPhotoUploader(),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _inviteCodeController,
          hint: 'Invite Code (optional)',
        ),
      ],
    );
  }

  Widget _buildEnhancedLocationPicker() {
    bool hasLocation = _latitude != null && _longitude != null;
    return InkWell(
      onTap: _isFetchingLocation ? null : _fetchLocation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasLocation ? Colors.green.withOpacity(0.1) : Colors.white10,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: hasLocation ? Colors.greenAccent : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (_isFetchingLocation)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00D189),
                ),
              )
            else
              Icon(
                hasLocation ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: hasLocation ? Colors.greenAccent : Colors.white54,
                size: 28,
              ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation ? "Location Secured" : "Capture Shop Location",
                    style: TextStyle(
                      color: hasLocation ? Colors.greenAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    hasLocation
                        ? "GPS Coordinates: ${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}"
                        : "Tap to fetch current coordinates",
                    style: TextStyle(
                      color: hasLocation ? Colors.greenAccent[100] : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (hasLocation)
              const Icon(Icons.check_circle, color: Colors.greenAccent),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isFetchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location fetched successfully!')),
      );
    } catch (e) {
      setState(() => _isFetchingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildCustomerFormFields() {
    return Column(
      children: [
        _buildTextField(controller: _nameController, hint: 'Full Name'),
        const SizedBox(height: 20),
        _buildTextField(controller: _emailController, hint: 'Email ID'),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController,
          hint: 'Password',
          obscureText: _obscurePassword,
          toggleObscure:
              () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _confirmPasswordController,
          hint: 'Confirm Password',
          obscureText: _obscureConfirm,
          toggleObscure:
              () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _pinCodeController,
          hint: 'PIN Code (for nearby search)',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _inviteCodeController,
          hint: 'Invite Code from Barber',
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildBarberFormShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade900,
      highlightColor: Colors.grey.shade800,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(12, (index) {
            return Container(
              height: 50,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 20, right: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          Container(
            height: 55,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchCityStateFromPincode(String pincode) async {
    try {
      final urlString = 'https://api.postalpincode.in/pincode/$pincode';

      final url = Uri.parse(urlString);
      debugPrint("📍 Fetching Pincode: $urlString");
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      debugPrint("📍 Response Code: ${response.statusCode}");
      debugPrint("📍 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data[0]['Status'] == 'Success') {
          final List<dynamic> postOffices = data[0]['PostOffice'];

          // Prioritize Head Post Office > Sub Post Office > Branch Post Office
          Map<String, dynamic> selectedPostOffice = postOffices.firstWhere(
            (element) => (element['BranchType'] as String)
                .toLowerCase()
                .contains('head post office'),
            orElse:
                () => postOffices.firstWhere(
                  (element) => (element['BranchType'] as String)
                      .toLowerCase()
                      .contains('sub post office'),
                  orElse: () => postOffices[0],
                ),
          );

          debugPrint(
            "📍 Selected PostOffice: ${selectedPostOffice['Name']}, Type: ${selectedPostOffice['BranchType']}",
          );

          String city = selectedPostOffice['Block'];
          if (city == 'NA' || city == 'null') {
            city = selectedPostOffice['District'];
          }

          setState(() {
            _cityController.text = city;
            _stateController.text = selectedPostOffice['State'];
          });
        } else {
          debugPrint("📍 API Status not Success: ${data[0]['Status']}");
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid PIN code')));
        }
      } else {
        debugPrint("📍 API Request Failed: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch details: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
      if (pincode == '388620') {
        debugPrint("📍 Applying local fallback for 388620");
        setState(() {
          _cityController.text = 'Khambhat';
          _stateController.text = 'Gujarat';
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching address: $e')));
      }
    }
  }

  Future<void> _checkAndCleanPreviousUploads() async {
    try {
      final doc = await BaasClient.collection('users').doc(widget.userId).get();

      final isProfileCompleted =
          (doc.data != null) && (doc.data!['profileCompleted'] == true);

      if (!isProfileCompleted) {
        await _cleanupPreviousUploads();
      }
    } catch (e) {
      debugPrint('Error checking profile status: $e');
    }
  }

  Future<void> _cleanupPreviousUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final tempPhotos = prefs.getStringList('temp_shop_photos') ?? [];

    if (tempPhotos.isEmpty) {
      debugPrint("🛑 No temp photos to clean.");
      return;
    }

    // TODO: Implement storage deletion in Baas SDK
    /*
    for (String url in tempPhotos) {
      try {
        debugPrint("🧹 Deleting: $url");
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint("❌ Failed to delete $url: $e");
      }
    }
    */

    await prefs.remove('temp_shop_photos');
    if (mounted) {
      setState(() => _shopPhotos.clear());
    }

    debugPrint("✅ Cleaned up temp uploaded photos (Local ref only)");
  }


}
