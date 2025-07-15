import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/customer/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

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

  final TextEditingController _shopAddressController = TextEditingController();
  List<String> _shopPhotos = [];
  double? _latitude;
  double? _longitude;

  bool _isSubmitting = false;

  List<File> _pendingPhotoFiles = [];

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Just a moment...',
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
                    'Will require a few details to get started',
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

              // 🔹 Fields (form or shimmer)
              if (widget.role.trim().toLowerCase() == 'customer')
                _isSubmitting
                    ? _buildCustomerFormShimmer()
                    : _buildCustomerFormFields()
              else
                _isSubmitting
                    ? _buildBarberFormShimmer()
                    : _buildBarberFormFields(),

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

  Widget _buildLocationPicker() {
    return _isFetchingLocation
        ? Shimmer.fromColors(
          baseColor: Colors.grey.shade800,
          highlightColor: Colors.grey.shade700,
          child: Container(
            height: 55,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        )
        : InkWell(
          onTap: () async {
            setState(() => _isFetchingLocation = true);

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Please wait...')));

            LocationPermission permission = await Geolocator.checkPermission();

            if (permission == LocationPermission.denied ||
                permission == LocationPermission.deniedForever) {
              permission = await Geolocator.requestPermission();
              if (permission == LocationPermission.denied ||
                  permission == LocationPermission.deniedForever) {
                setState(() => _isFetchingLocation = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Location permission is required to pick your shop location.',
                    ),
                  ),
                );
                return;
              }
            }

            try {
              final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );

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
              setState(() => _isFetchingLocation = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to get location: $e')),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white54),
                const SizedBox(width: 10),
                Text(
                  _latitude != null
                      ? 'Location: ($_latitude, $_longitude)'
                      : 'Tap to pick shop location',
                  style: const TextStyle(color: Colors.white70),
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
    );
  }

  Future<void> _handleSubmit() async {
    final role = widget.role.trim().toLowerCase();
    final uid = widget.userId;

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
    }

    if (role == 'barber') {
      if (_shopAddressController.text.trim().isEmpty ||
          _latitude == null ||
          _longitude == null ||
          _pendingPhotoFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all barber details')),
        );
        return;
      }

      final email = _emailController.text.trim();

      // 🔍 Check if email already exists in Firestore
      final emailSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (emailSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email already exists. Please use a different email ID.',
            ),
          ),
        );
        return; // Stop submission
      }
    }

    final fullAddress = [
      _shopNumberController.text.trim(),
      _buildingNameController.text.trim(),
      _localityController.text.trim(),
      _landmarkController.text.trim(),
      _cityController.text.trim(),
      _stateController.text.trim(),
      _pinCodeController.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');

    setState(() => _isSubmitting = true);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Please wait...")));

    await Future.delayed(const Duration(milliseconds: 500));

    final Map<String, dynamic> userData = {
      'uid': uid,
      'phone': '+91${widget.phoneNumber}',
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'userType': role,
      'hasPassword': true,
      'profileCompleted': true,
      'createdAt': FieldValue.serverTimestamp(),
    };

    List<String> uploadedUrls = [];

    for (File file in _pendingPhotoFiles) {
      final fileName = path.basename(file.path);
      final ref = FirebaseStorage.instance.ref().child(
        'shop_photos/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      final snapshot = await ref.putFile(file);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      uploadedUrls.add(downloadUrl);
    }

    if (role == 'barber') {
      userData.addAll({
        'shopName': _shopNameController.text.trim(),
        'shopAddress': fullAddress,
        'location': {'lat': _latitude, 'lng': _longitude},
        'shopPhotos': uploadedUrls,
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(userData, SetOptions(merge: true));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', uid);
    await prefs.setString('role', role);
    await prefs.setBool('isLoggedIn', true);

    await prefs.setString('barberName', _nameController.text.trim());
    await prefs.setString('shopName', _shopNameController.text.trim());
    await prefs.setString('email', _emailController.text.trim());
    await prefs.setString('phone', widget.phoneNumber);
    await prefs.setDouble('lat', _latitude!);
    await prefs.setDouble('lng', _longitude!);
    await prefs.setStringList('shopPhotos', uploadedUrls);
    await prefs.setBool('isActive', true);
    await prefs.setString('userType', 'barber');
    await prefs.setString('userId', FirebaseAuth.instance.currentUser!.uid);
    await prefs.setBool('isLoggedIn', true);

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
      final url = Uri.parse('https://api.postalpincode.in/pincode/$pincode');
      final response = await http.get(url);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching address: $e')));
    }
  }

  void _previewOrDeletePhoto(String url) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.black87,
            title: const Text(
              'Photo Options',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(url, height: 150),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // close dialog

                    try {
                      final ref = FirebaseStorage.instance.refFromURL(url);
                      await ref.delete();
                    } catch (e) {
                      debugPrint("Firebase delete failed: $e");
                    }

                    setState(() => _shopPhotos.remove(url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Photo removed')),
                    );
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Photo'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _checkAndCleanPreviousUploads() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();

      final isProfileCompleted =
          doc.exists && (doc.data()?['profileCompleted'] == true);

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
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint("❌ Failed to delete $url: $e");
      }
    }

    await prefs.remove('temp_shop_photos');
    setState(() => _shopPhotos.clear());

    debugPrint("✅ Cleaned up temp uploaded photos");
  }
}
