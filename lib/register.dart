import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kesh_kart/access/role_landing.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/legal_document_page.dart';
import 'package:kesh_kart/customer/signup_terms_consent.dart';
import 'package:kesh_kart/services/notification_service.dart';

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

  bool _isFetchingLocation = false;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  double _iconOpacity = 0.0;
  late final Timer _timer;
  int _secondsRemaining = 30;
  double _taglineOpacity = 0.0;

  final List<String> _shopPhotos = [];
  double? _latitude;
  double? _longitude;

  bool _isSubmitting = false;
  bool _termsAccepted = false;

  final List<File> _pendingPhotoFiles = [];

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
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Just a moment...',
          style: TextStyle(
            color: Color(0xFF091426),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // 🔹 Sign Up Illustration
                      AnimatedOpacity(
                        opacity: _iconOpacity,
                        duration: const Duration(milliseconds: 600),
                        child: Image.asset(
                          'assets/images/SignUp.png',
                          height: 200,
                        ),
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
                            'Will require a few details to get started',
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

                      const SizedBox(height: 20),

                      // 🔹 Fields (form or shimmer)
                      if (widget.role.trim().toLowerCase() == 'customer')
                        _isSubmitting
                            ? _buildCustomerFormShimmer()
                            : _buildCustomerFormFields()
                      else
                        _isSubmitting
                            ? _buildBarberFormShimmer()
                            : _buildBarberFormFields(),

                      const SizedBox(height: 18),
                      SignupTermsConsent(
                        audience:
                            widget.role.trim().toLowerCase() == 'barber'
                                ? LegalAudience.barber
                                : LegalAudience.customer,
                        accepted: _termsAccepted,
                        onChanged: (accepted) {
                          setState(() => _termsAccepted = accepted);
                        },
                      ),

                      const Spacer(),

                      // 🔹 Submit button (always visible)
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
      style: const TextStyle(color: Color(0xFF091426)),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black45),
        suffixIcon:
            toggleObscure != null
                ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.black45,
                  ),
                  onPressed: toggleObscure,
                )
                : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0A66C2), width: 1.4),
        ),
      ),
    );
  }

  void _startResendTimer() {
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

  Widget _buildLocationPicker({String? emptyLabel}) {
    return _isFetchingLocation
        ? Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 55,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        )
        : InkWell(
          onTap: () async {
            setState(() => _isFetchingLocation = true);

            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Please wait...')));
            }

            LocationPermission permission = await Geolocator.checkPermission();

            if (permission == LocationPermission.denied ||
                permission == LocationPermission.deniedForever) {
              permission = await Geolocator.requestPermission();
              if (permission == LocationPermission.denied ||
                  permission == LocationPermission.deniedForever) {
                if (mounted) {
                  setState(() => _isFetchingLocation = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Location permission is required to continue.',
                      ),
                    ),
                  );
                }
                return;
              }
            }

            try {
              final position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                ),
              );

              if (!mounted) return;

              setState(() {
                _latitude = position.latitude;
                _longitude = position.longitude;
                _isFetchingLocation = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location selected successfully!'),
                ),
              );
            } catch (e) {
              if (mounted) {
                setState(() => _isFetchingLocation = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to get location: $e')),
                );
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF0A66C2)),
                const SizedBox(width: 10),
                Text(
                  _latitude != null
                      ? 'Location: ($_latitude, $_longitude)'
                      : (emptyLabel ?? 'Tap to pick location'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildPhotoUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload shop photos (max 5):',
          style: TextStyle(color: Colors.black54),
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
                    child: Image.file(
                      file,
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
                        _pendingPhotoFiles.add(File(image.path));
                      });
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_a_photo,
                      color: Color(0xFF0A66C2),
                    ),
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
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
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
          onTap: _isSubmitting ? null : _handleSubmit,
          child: Opacity(
            opacity: _isSubmitting ? 0.5 : 1.0,
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
    );
  }

  Future<void> _handleSubmit() async {
    final role = widget.role.trim().toLowerCase();
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Conditions to continue.'),
        ),
      );
      return;
    }
    final uid = widget.userId;
    final fullAddress = [
      _shopNumberController.text.trim(),
      _buildingNameController.text.trim(),
      _localityController.text.trim(),
      _landmarkController.text.trim(),
      _cityController.text.trim(),
      _stateController.text.trim(),
      _pinCodeController.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');

    if (role == 'customer') {
      if (_nameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text != _passwordController.text ||
          _latitude == null ||
          _longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all fields and pick your location'),
          ),
        );
        return;
      }
    }

    if (role == 'barber') {
      if (_shopNameController.text.trim().isEmpty ||
          _nameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text != _passwordController.text ||
          _cityController.text.trim().isEmpty ||
          _stateController.text.trim().isEmpty ||
          _pinCodeController.text.trim().isEmpty ||
          fullAddress.isEmpty ||
          _latitude == null ||
          _longitude == null ||
          _pendingPhotoFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all barber details')),
        );
        return;
      }

      final email = _emailController.text.trim();

      // 🔍 Check if email already exists in Bedrock
      final existingUsers = await BedrockClient().queryCollection(
        'users',
        params: {'email': email},
      );

      if (existingUsers.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email already exists. Please use a different email ID.',
              ),
            ),
          );
        }
        return; // Stop submission
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Please wait...")));

    await Future.delayed(const Duration(milliseconds: 500));

    final Map<String, dynamic> userData = {
      'uid': uid,
      'phone': widget.phoneNumber,
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'userType': role,
      'hasPassword': true,
      'profileCompleted': true,
      'termsAccepted': true,
      'termsVersion': '2026-09-24',
      'termsAcceptedAt': DateTime.now().toUtc().toIso8601String(),
      'privacyAcknowledged': true,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final pincode = _pinCodeController.text.trim();
    final locality = _localityController.text.trim();
    final locationLabel = [
      city,
      pincode,
    ].where((part) => part.isNotEmpty).join(' - ');

    if (_latitude != null && _longitude != null) {
      userData['location'] = {
        'lat': _latitude,
        'lng': _longitude,
        'city': city,
        'state': state,
        'pincode': pincode,
        'locality': locality,
        'address': fullAddress,
        'label': locationLabel.isEmpty ? fullAddress : locationLabel,
      };
    }

    List<String> uploadedUrls = [];

    for (File file in _pendingPhotoFiles) {
      final fileName = path.basename(file.path);
      final storagePath =
          'shop_photos/$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      debugPrint(
        '[KeshKartUpload] register upload uid=$uid localPath=${file.path} '
        'storagePath=$storagePath',
      );
      final downloadUrl = await BedrockClient().uploadFile(file, storagePath);

      if (downloadUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to upload shop photo to Bedrock."),
            ),
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }

      // The upload response URL is deliberately signed and temporary. Keep
      // the durable path in the profile so it can be re-signed later.
      uploadedUrls.add(storagePath);
      debugPrint(
        '[KeshKartUpload] register upload saved count=${uploadedUrls.length}',
      );
    }

    if (role == 'barber') {
      userData.addAll({
        'shopName': _shopNameController.text.trim(),
        'shopAddress': fullAddress,
        'location': {
          'lat': _latitude,
          'lng': _longitude,
          'city': city,
          'state': state,
          'pincode': pincode,
          'locality': locality,
          'address': fullAddress,
          'label': locationLabel.isEmpty ? fullAddress : locationLabel,
        },
        'shopPhotos': uploadedUrls,
        'verificationStatus': 'unverified',
        'isDiscoverable': false,
      });
    }

    // 🧱 SAVE TO BEDROCK
    // Use the UID as the document ID for the 'users' collection
    final result = await BedrockClient().updateDocument('users', uid, userData);

    if (result == null) {
      // If update fails (might be because doc doesn't exist yet), try create or handle error
      debugPrint("Bedrock Save Failed. Check your rules and API connectivity.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save profile to Bedrock.")),
        );
        setState(() => _isSubmitting = false);
      }
      return;
    }

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', uid);
    await prefs.setString('role', role);
    await prefs.setBool('isLoggedIn', true);

    await prefs.setString('name', _nameController.text.trim());
    await prefs.setString('barberName', _nameController.text.trim());
    await prefs.setString('shopName', _shopNameController.text.trim());
    await prefs.setString('email', _emailController.text.trim());
    await prefs.setString('phone', widget.phoneNumber);
    if (_latitude != null && _longitude != null) {
      await prefs.setDouble('lat', _latitude!);
      await prefs.setDouble('lng', _longitude!);
      await prefs.setString(
        'locationLabel',
        locationLabel.isEmpty ? 'Location saved' : locationLabel,
      );
    }
    await prefs.setStringList('shopPhotos', uploadedUrls);
    await prefs.setBool('isActive', true);
    await prefs.setString('userType', role);
    await prefs.setBool('isLoggedIn', true);
    if (role == 'barber' && !kIsWeb) {
      await NotificationService.requestPermissionAndSyncToken();
    }

    if (!mounted) return;

    if (!kIsWeb || role == 'barber') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoleLanding.barber()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoleLanding.customer()),
      );
    }
  }

  Widget _buildBarberFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(controller: _shopNameController, hint: 'Shop Name'),
        const SizedBox(height: 20),
        SizedBox(height: 20),
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
          hint: 'PIN Code',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.postalCode],
          // onSubmitted: (value) {
          //   if (value.trim().length == 6) {
          //     _fetchCityStateFromPincode(value.trim());
          //   }
          // },
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _cityController,
                hint: 'City',
                keyboardType: TextInputType.text,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                controller: _stateController,
                hint: 'State',
                keyboardType: TextInputType.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _buildTextField(
          controller: _shopNumberController,
          hint: 'Shop No. / Flat No.',
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _buildingNameController,
          hint: 'Building / Apartment Name',
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _landmarkController,
          hint: 'Landmark (optional)',
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _localityController,
          hint: 'Locality / Area',
        ),
        const SizedBox(height: 20),

        const SizedBox(height: 20),
        _buildLocationPicker(),
        const SizedBox(height: 20),
        _buildPhotoUploader(),
      ],
    );
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
        _buildLocationPicker(emptyLabel: 'Tap to pick your location'),
      ],
    );
  }

  Widget _buildBarberFormShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(12, (index) {
            return Container(
              height: 50,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
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
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
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
              color: Colors.grey.shade200,
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
                    color: Colors.grey.shade200,
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
      final url = Uri.parse('https://api.postalpincode.in/pincode/$pincode');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data[0]['Status'] == 'Success') {
          final postOffice = data[0]['PostOffice'][0];
          setState(() {
            _cityController.text = postOffice['District'];
            _stateController.text = postOffice['State'];
          });
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid PIN code')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching address: $e')));
      }
    }
  }

  Future<void> _checkAndCleanPreviousUploads() async {
    try {
      final doc = await BedrockClient().getDocument('users', widget.userId);

      final isProfileCompleted =
          doc != null && (doc['data']?['profileCompleted'] == true);

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

    for (String url in tempPhotos) {
      try {
        debugPrint("🧹 Deleting: $url");
        debugPrint(
          "Skipping Bedrock object deletion for previous temp upload: $url",
        );
      } catch (e) {
        debugPrint("❌ Failed to delete $url: $e");
      }
    }

    await prefs.remove('temp_shop_photos');
    setState(() => _shopPhotos.clear());

    debugPrint("✅ Cleaned up temp uploaded photos");
  }
}
