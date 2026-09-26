import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/legal_document_page.dart';
import 'package:kesh_kart/customer/signup_terms_consent.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android-only barber onboarding. It deliberately has no customer dependency.
class BarberRegistrationScreen extends StatefulWidget {
  final String phoneNumber;
  final String userId;

  const BarberRegistrationScreen({
    super.key,
    required this.phoneNumber,
    required this.userId,
  });

  @override
  State<BarberRegistrationScreen> createState() =>
      _BarberRegistrationScreenState();
}

class _BarberRegistrationScreenState extends State<BarberRegistrationScreen> {
  static const _maxShopPhotos = 5;

  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _picker = ImagePicker();

  final List<File> _shopPhotos = [];
  Position? _location;
  bool _isSaving = false;
  bool _isLocating = false;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _shopName.dispose();
    _ownerName.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_shopPhotos.length >= _maxShopPhotos) {
      _showMessage('You can upload up to $_maxShopPhotos shop photos.');
      return;
    }
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (image == null || !mounted) return;
    setState(() => _shopPhotos.add(File(image.path)));
  }

  void _removePhoto(int index) {
    setState(() => _shopPhotos.removeAt(index));
  }

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Turn on location services and try again.');

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
    if (!_termsAccepted) {
      _showMessage('Please accept the Barber Terms & Conditions to continue.');
      return;
    }
    if (_shopPhotos.isEmpty) {
      _showMessage('Add at least one clear photo of the shop.');
      return;
    }
    if (_location == null) {
      _showMessage('Capture the shop location before continuing.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uploadedPaths = <String>[];
      for (final entry in _shopPhotos.asMap().entries) {
        final photo = entry.value;
        final filename = photo.path.split(RegExp(r'[/\\]')).last;
        final storagePath =
            'shop_photos/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}_${entry.key}_$filename';
        final photoUrl = await BedrockClient().uploadFile(photo, storagePath);
        if (photoUrl == null) {
          throw Exception('A shop photo could not be uploaded. Please retry.');
        }
        // Verify the upload through its temporary URL, but persist the stable
        // storage path. Signed download URLs expire and must never be profile
        // data.
        uploadedPaths.add(storagePath);
      }

      final location = _location!;
      final shopName = _shopName.text.trim();
      final address = _address.text.trim();
      final city = _city.text.trim();
      final payload = <String, dynamic>{
        'uid': widget.userId,
        'phone': widget.phoneNumber,
        'name': _ownerName.text.trim(),
        'email': _email.text.trim(),
        'userType': 'barber',
        'profileCompleted': true,
        'termsAccepted': true,
        'termsVersion': '2026-09-24',
        'termsAcceptedAt': DateTime.now().toUtc().toIso8601String(),
        'privacyAcknowledged': true,
        'hasPassword': true,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'shopName': shopName,
        'shopAddress': address,
        'shopPhotos': uploadedPaths,
        'verificationStatus': 'unverified',
        'isDiscoverable': false,
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
          'city': city,
          'address': address,
          'label': city.isEmpty ? address : '$city - $address',
        },
      };

      final saved = await BedrockClient().updateDocument(
        'users',
        widget.userId,
        payload,
      );
      if (saved == null) {
        throw Exception('Your barber profile could not be saved.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', widget.userId);
      await prefs.setString('bedrock_user_id', widget.userId);
      await prefs.setString('role', 'barber');
      await prefs.setString('userType', 'barber');
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('name', _ownerName.text.trim());
      await prefs.setString('barberName', _ownerName.text.trim());
      await prefs.setString('shopName', shopName);
      await prefs.setString('email', _email.text.trim());
      await prefs.setString('phone', widget.phoneNumber);
      await prefs.setDouble('lat', location.latitude);
      await prefs.setDouble('lng', location.longitude);
      await prefs.setString(
        'locationLabel',
        city.isEmpty ? address : '$city - $address',
      );
      await prefs.setStringList('shopPhotos', uploadedPaths);

      await NotificationService.requestPermissionAndSyncToken();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your barber shop')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Create your barber profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'This account will manage bookings and scan customer receipts.',
                style: TextStyle(color: Colors.blueGrey.shade700),
              ),
              const SizedBox(height: 24),
              _field(_shopName, 'Shop name'),
              _field(_ownerName, 'Owner name'),
              _field(
                _email,
                'Email address',
                keyboard: TextInputType.emailAddress,
              ),
              _field(_address, 'Shop address', maxLines: 2),
              _field(_city, 'City'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isLocating ? null : _captureLocation,
                icon:
                    _isLocating
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(
                          _location == null
                              ? Icons.my_location_outlined
                              : Icons.location_on,
                        ),
                label: Text(
                  _location == null
                      ? 'Capture shop location'
                      : 'Shop location captured',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Shop gallery (${_shopPhotos.length}/$_maxShopPhotos)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add up to five clear shop photos. You will capture a separate live shop-front verification photo with the camera after setup.',
                style: TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    _shopPhotos.length >= _maxShopPhotos ? null : _pickPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _shopPhotos.isEmpty
                      ? 'Add shop photo'
                      : 'Add another photo (${_shopPhotos.length}/$_maxShopPhotos)',
                ),
              ),
              if (_shopPhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in _shopPhotos.asMap().entries)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              entry.value,
                              height: 104,
                              width: 104,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton.filled(
                              tooltip: 'Remove photo',
                              onPressed: () => _removePhoto(entry.key),
                              icon: const Icon(Icons.close, size: 18),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SignupTermsConsent(
                audience: LegalAudience.barber,
                accepted: _termsAccepted,
                onChanged: (accepted) {
                  setState(() => _termsAccepted = accepted);
                },
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child:
                      _isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Finish setup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator:
            (value) =>
                value == null || value.trim().isEmpty
                    ? '$label is required'
                    : null,
      ),
    );
  }
}
