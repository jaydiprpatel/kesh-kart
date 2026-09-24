import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browser onboarding for a new barber account.
///
/// The flow mirrors the native shop-profile contract while using XFile bytes,
/// which are supported by browser file pickers.
class BarberWebOnboardingScreen extends StatefulWidget {
  final String phoneNumber;
  final String userId;

  const BarberWebOnboardingScreen({
    super.key,
    required this.phoneNumber,
    required this.userId,
  });

  @override
  State<BarberWebOnboardingScreen> createState() =>
      _BarberWebOnboardingScreenState();
}

class _BarberWebOnboardingScreenState extends State<BarberWebOnboardingScreen> {
  static const _ink = Color(0xFF091426);
  static const _coral = Color(0xFFE2613B);

  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pinCode = TextEditingController();
  final _picker = ImagePicker();

  XFile? _shopPhoto;
  Uint8List? _shopPhotoBytes;
  Position? _location;
  bool _isLocating = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _shopName.dispose();
    _ownerName.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pinCode.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1800,
    );
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    if (bytes.isEmpty) {
      _showMessage('That image could not be read. Please choose another one.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _shopPhoto = photo;
      _shopPhotoBytes = bytes;
    });
  }

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on location services and try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to register a shop.');
      }

      final location = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) setState(() => _location = location);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final photo = _shopPhoto;
    final photoBytes = _shopPhotoBytes;
    final location = _location;
    if (photo == null || photoBytes == null) {
      _showMessage('Add one clear photo of your shop before continuing.');
      return;
    }
    if (location == null) {
      _showMessage('Capture your shop location before continuing.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final filename = photo.name.isEmpty ? 'shop.jpg' : photo.name;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'shop_photos/${widget.userId}/${timestamp}_$filename';
      final photoUrl = await BedrockClient().uploadBytes(
        photoBytes,
        storagePath,
        filename: filename,
        contentType: _contentType(filename),
      );
      if (photoUrl == null) {
        throw Exception('The shop photo could not be uploaded. Please retry.');
      }

      final shopName = _shopName.text.trim();
      final ownerName = _ownerName.text.trim();
      final address = _address.text.trim();
      final city = _city.text.trim();
      final state = _state.text.trim();
      final pinCode = _pinCode.text.trim();
      final label = '$shopName, $address, $city, $state - $pinCode';
      final saved = await BedrockClient().updateDocument(
        'users',
        widget.userId,
        {
          'uid': widget.userId,
          'phone': widget.phoneNumber,
          'name': ownerName,
          'email': _email.text.trim(),
          'userType': 'barber',
          'profileCompleted': true,
          'profileCompletedAt': DateTime.now().toUtc().toIso8601String(),
          'shopName': shopName,
          'shopAddress': address,
          // Store the durable path, not the short-lived signed download URL.
          'shopPhotos': [storagePath],
          'verificationStatus': 'unverified',
          'isDiscoverable': false,
          'isActive': false,
          'isOpen': false,
          'location': {
            'lat': location.latitude,
            'lng': location.longitude,
            'accuracyMeters': location.accuracy,
            'city': city,
            'state': state,
            'pinCode': pinCode,
            'address': address,
            'label': label,
          },
        },
      );
      if (saved == null) {
        throw Exception('Your barber profile could not be saved.');
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('userId', widget.userId);
      await preferences.setString('bedrock_user_id', widget.userId);
      await preferences.setString('role', 'barber');
      await preferences.setString('userType', 'barber');
      await preferences.setBool('isLoggedIn', true);
      await preferences.setBool('isActive', false);
      await preferences.setString('name', ownerName);
      await preferences.setString('barberName', shopName);
      await preferences.setString('shopName', shopName);
      await preferences.setString('email', _email.text.trim());
      await preferences.setString('phone', widget.phoneNumber);
      await preferences.setDouble('lat', location.latitude);
      await preferences.setDouble('lng', location.longitude);
      await preferences.setString('locationLabel', label);
      await preferences.setStringList('shopPhotos', [storagePath]);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BarberHome()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _contentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back'),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Create your barber shop',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Set up your business on the web. You can then manage services, bookings, shop availability, verification, and your KeshKart Pro subscription here.',
                            style: TextStyle(
                              color: Color(0xFF54647A),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFE0E7F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Business details',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _field(_shopName, 'Shop name'),
                                _field(_ownerName, 'Owner name'),
                                _field(
                                  _email,
                                  'Business email',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (!email.contains('@') ||
                                        !email.contains('.')) {
                                      return 'Enter a valid business email.';
                                    }
                                    return null;
                                  },
                                ),
                                _field(_address, 'Shop address', maxLines: 2),
                                LayoutBuilder(
                                  builder: (context, fields) {
                                    final wide = fields.maxWidth >= 620;
                                    final inputs = [
                                      _field(_city, 'City'),
                                      _field(_state, 'State'),
                                      _field(
                                        _pinCode,
                                        'PIN code',
                                        keyboardType: TextInputType.number,
                                        validator:
                                            (value) =>
                                                RegExp(r'^\d{6}$').hasMatch(
                                                      value?.trim() ?? '',
                                                    )
                                                    ? null
                                                    : 'Enter a 6-digit PIN code.',
                                      ),
                                    ];
                                    if (!wide) return Column(children: inputs);
                                    return Row(
                                      children: [
                                        Expanded(child: inputs[0]),
                                        const SizedBox(width: 12),
                                        Expanded(child: inputs[1]),
                                        const SizedBox(width: 12),
                                        Expanded(child: inputs[2]),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                _locationPanel(),
                                const SizedBox(height: 16),
                                _photoPanel(),
                                const SizedBox(height: 22),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7F3),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.verified_user_outlined,
                                        color: _coral,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'After saving, submit a current shop verification photo from your Profile. Your shop remains private until it is approved.',
                                          style: TextStyle(
                                            color: _ink,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _isSaving ? null : _save,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _ink,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                    ),
                                    child:
                                        _isSaving
                                            ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : const Text(
                                              'Save shop and open dashboard',
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(
                                        context,
                                      ).pushNamed('/terms'),
                                  child: const Text('Terms & Conditions'),
                                ),
                                const Text(
                                  '•',
                                  style: TextStyle(color: Color(0xFF7B8798)),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(
                                        context,
                                      ).pushNamed('/privacy'),
                                  child: const Text('Privacy Policy'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator:
            validator ??
            (value) =>
                (value?.trim().isEmpty ?? true) ? '$label is required.' : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFFBFCFE),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _locationPanel() {
    final location = _location;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5F0)),
      ),
      child: Row(
        children: [
          Icon(
            location == null
                ? Icons.location_searching_rounded
                : Icons.location_on_rounded,
            color: _coral,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              location == null
                  ? 'Capture the live shop location for verification.'
                  : 'Location captured to ${location.accuracy.round()}m accuracy.',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _isLocating ? null : _captureLocation,
            child:
                _isLocating
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(location == null ? 'Use location' : 'Update'),
          ),
        ],
      ),
    );
  }

  Widget _photoPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shop photo',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload a clear photo of your storefront or work area. JPEG, PNG, and WebP up to 10MB are supported.',
            style: TextStyle(color: Color(0xFF54647A), height: 1.35),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _shopPhoto == null ? 'Choose shop photo' : 'Choose another photo',
            ),
          ),
          if (_shopPhotoBytes != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _shopPhotoBytes!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
