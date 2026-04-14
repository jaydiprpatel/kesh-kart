import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:path/path.dart' as path;

class BarberVerificationScreen extends StatefulWidget {
  final String barberId;
  const BarberVerificationScreen({super.key, required this.barberId});

  @override
  State<BarberVerificationScreen> createState() =>
      _BarberVerificationScreenState();
}

class _BarberVerificationScreenState extends State<BarberVerificationScreen> {
  XFile? _shopFrontPhoto;
  Position? _capturedPosition;
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _capturePhoto() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      // 1. Check Location Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(
            () =>
                _errorMessage =
                    "Location permission is required for verification.",
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(
          () =>
              _errorMessage =
                  "Location permissions are permanently denied. Please enable them in settings.",
        );
        return;
      }

      // 2. Capture precise location FIRST (to ensure they are AT the shop)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // 3. Open Camera (Gallery Disabled)
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        setState(() {
          _shopFrontPhoto = photo;
          _capturedPosition = position;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Error capturing verification data: $e");
    }
  }

  Future<void> _submitVerification() async {
    if (_shopFrontPhoto == null || _capturedPosition == null) return;

    setState(() => _isProcessing = true);

    try {
      final fileName = path.basename(_shopFrontPhoto!.path);
      final storagePath =
          'verifications/${widget.barberId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = BaasClient.instance.sdk.storage.ref(storagePath);

      final bytes = await _shopFrontPhoto!.readAsBytes();
      final storedFile = await ref.putBytes(bytes, contentType: 'image/jpeg');

      // Create Verification Record
      await BaasClient.collection('barber_verifications').add({
        'barberId': widget.barberId,
        'photoUrl': storedFile.downloadUrl,
        'latitude': _capturedPosition!.latitude,
        'longitude': _capturedPosition!.longitude,
        'capturedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      // Update User Status
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'verificationStatus': 'pending'});

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to submit verification: $e";
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Shop Verification",
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Authenticity is Mandatory",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "To protect Kesh-Kart's trust circle, every barber must verify their physical shop location. Please capture a clear photo of your shop's front while standing outside.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            Expanded(
              child: Center(
                child:
                    _shopFrontPhoto == null
                        ? _buildEmptyState()
                        : _buildPreview(),
              ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            ElevatedButton(
              onPressed:
                  (_isProcessing || _shopFrontPhoto == null)
                      ? null
                      : _submitVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D189),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.white12,
              ),
              child:
                  _isProcessing
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text(
                        "Submit for Verification",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return InkWell(
      onTap: _capturePhoto,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              "Tap to Open Camera",
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Live GPS will be captured",
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(
            File(_shopFrontPhoto!.path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            onPressed: () => setState(() => _shopFrontPhoto = null),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.greenAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  "Precise Location Captured",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
