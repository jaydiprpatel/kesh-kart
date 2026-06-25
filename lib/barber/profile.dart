import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kesh_kart/barber/service.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:path/path.dart' as path;

class BarberProfileScreen extends StatefulWidget {
  final String barberId;
  const BarberProfileScreen({super.key, required this.barberId});

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  String? name;
  String? address;
  String? profileUrl;
  double rating = 0.0;
  int totalReviews = 0;
  List<String> shopPhotos = [];
  String verificationStatus = 'unverified';
  String? verificationNote;
  bool isUploading = false;
  bool isLoading = true;
  bool imageLoading = false;
  bool isSubmittingVerification = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await BedrockClient().getDocument('users', widget.barberId);
      if (doc == null) {
        debugPrint(
          '[KeshKartUpload] profile load failed: document not found for ${widget.barberId}',
        );
        return;
      }

      final data = doc['data'] ?? {};
      final rawShopPhotos = List<String>.from(data['shopPhotos'] ?? []);
      final resolvedShopPhotos = await _resolveShopPhotos(rawShopPhotos);
      debugPrint(
        '[KeshKartUpload] profile loaded barberId=${widget.barberId} '
        'rawPhotos=${rawShopPhotos.length} resolvedPhotos=${resolvedShopPhotos.length}',
      );
      debugPrint('Barber Profile: $data');
      if (!mounted) return;
      setState(() {
        name = data['name'];
        address = data['shopAddress'];
        profileUrl = data['profileUrl'];
        rating = _toDouble(data['averageRating']) ?? 0.0;
        totalReviews = _toInt(data['totalReviews']) ?? 0;
        shopPhotos = resolvedShopPhotos;
        verificationStatus =
            data['verificationStatus']?.toString() ?? 'unverified';
        verificationNote = data['shopVerificationNote']?.toString();
        isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('barber_profile', doc['data'].toString());
    } catch (e) {
      debugPrint('[KeshKartUpload] profile load error: $e');
    } finally {
      if (mounted && isLoading) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _submitShopVerification() async {
    if (isSubmittingVerification) return;

    setState(() => isSubmittingVerification = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint(
        '[KeshKartUpload] verification permission initial=$permission',
      );
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        debugPrint(
          '[KeshKartUpload] verification permission requested=$permission',
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required for shop verification',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      debugPrint(
        '[KeshKartUpload] verification location '
        'lat=${position.latitude} lng=${position.longitude} '
        'accuracy=${position.accuracy}',
      );
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) {
        debugPrint('[KeshKartUpload] verification camera cancelled');
        setState(() => isSubmittingVerification = false);
        return;
      }

      final file = File(image.path);
      final fileExists = await file.exists();
      final fileSize = fileExists ? await file.length() : -1;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final photoPath =
          'shop_verifications/${widget.barberId}/${timestamp}_${path.basename(image.path)}';
      debugPrint(
        '[KeshKartUpload] verification selected barberId=${widget.barberId} '
        'localPath=${image.path} exists=$fileExists bytes=$fileSize '
        'storagePath=$photoPath',
      );
      final photoUrl = await BedrockClient().uploadFile(file, photoPath);
      if (photoUrl == null) {
        throw Exception('Failed to upload verification photo');
      }
      debugPrint(
        '[KeshKartUpload] verification upload success storagePath=$photoPath',
      );

      final response = await BedrockClient().submitShopVerification(
        photoUrl: photoUrl,
        photoPath: photoPath,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      debugPrint('[KeshKartUpload] verification submit response=$response');
      if (response == null || response['success'] != true) {
        throw Exception(response?['error'] ?? 'Verification submit failed');
      }

      setState(() {
        verificationStatus = 'pending';
        verificationNote = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop verification submitted for review')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isSubmittingVerification = false);
    }
  }

  void _removeShopPhoto(int index) async {
    final confirmed = await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.black,
            title: const Text(
              'Remove Photo?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to remove this photo?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      shopPhotos.removeAt(index);
      await BedrockClient().updateDocument('users', widget.barberId, {
        'shopPhotos': shopPhotos,
      });

      setState(() {});
    }
  }

  void _addShopPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // 👉 Add temporary shimmer placeholder
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final filename = '${tempId}_${path.basename(image.path)}';
      final storagePath = 'shop_photos/${widget.barberId}/$filename';
      debugPrint(
        '[KeshKartUpload] gallery selected barberId=${widget.barberId} '
        'localPath=${image.path} storagePath=$storagePath',
      );
      setState(() {
        shopPhotos.add('shimmer_$tempId'); // show shimmer
      });

      try {
        final newUrl = await BedrockClient().uploadFile(
          File(image.path),
          storagePath,
        );
        if (newUrl == null) {
          throw Exception('Bedrock upload failed');
        }

        // Replace shimmer placeholder with real image
        final index = shopPhotos.indexWhere((e) => e == 'shimmer_$tempId');
        if (index != -1) shopPhotos[index] = newUrl;
        debugPrint(
          '[KeshKartUpload] gallery replace index=$index total=${shopPhotos.length}',
        );

        final updateResult = await BedrockClient().updateDocument(
          'users',
          widget.barberId,
          {'shopPhotos': shopPhotos},
        );
        debugPrint(
          '[KeshKartUpload] gallery profile update '
          'success=${updateResult != null} photoCount=${shopPhotos.length}',
        );

        setState(() {});
      } catch (e) {
        debugPrint('Upload failed: $e');
        // remove the placeholder shimmer if failed
        shopPhotos.removeWhere((e) => e.startsWith('shimmer_'));
        setState(() {});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo upload failed. Please try again in a few minutes.',
            ),
          ),
        );
      }
    }
  }

  Future<List<String>> _resolveShopPhotos(List<String> photos) async {
    final resolved = <String>[];
    for (final photo in photos) {
      if (!_isUsableShopPhoto(photo)) {
        debugPrint('[KeshKartUpload] profile dropped legacy photo=$photo');
        continue;
      }
      try {
        final refreshed = await BedrockClient().getDownloadUrl(photo);
        resolved.add(refreshed ?? photo);
      } catch (e) {
        debugPrint('[KeshKartUpload] profile photo refresh failed: $e');
        resolved.add(photo);
      }
    }
    return resolved;
  }

  bool _isUsableShopPhoto(String photo) {
    final value = photo.trim();
    if (value.isEmpty || value.startsWith('shimmer_')) return false;
    return value.contains('/shop_photos/${widget.barberId}/') ||
        value.contains('/shop_verifications/${widget.barberId}/') ||
        value.startsWith('shop_photos/${widget.barberId}/') ||
        value.startsWith('shop_verifications/${widget.barberId}/');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Your Profile",
          style: TextStyle(
            color: Color(0xFF091426),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF8F9FA),
        iconTheme: const IconThemeData(color: Color(0xFF091426)),
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF091426)),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipOval(
                      child:
                          (isUploading || imageLoading || profileUrl == null)
                              ? Shimmer.fromColors(
                                baseColor: Colors.grey[700]!,
                                highlightColor: Colors.grey[500]!,
                                child: Container(
                                  height: 100,
                                  width: 100,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : Image.network(
                                profileUrl!,
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  if (imageLoading) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(
                                              () => imageLoading = false,
                                            );
                                          }
                                        });
                                  }
                                  return Container(
                                    height: 100,
                                    width: 100,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (imageLoading) {
                                            setState(
                                              () => imageLoading = false,
                                            );
                                          }
                                        });
                                    return child;
                                  } else {
                                    return Shimmer.fromColors(
                                      baseColor: Colors.grey[700]!,
                                      highlightColor: Colors.grey[500]!,
                                      child: Container(
                                        height: 100,
                                        width: 100,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF091426),
                      ),
                    ),
                    const SizedBox(height: 6),
                    totalReviews == 0
                        ? const Text(
                          '⭐ No reviews yet — your experience matters!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF54647A),
                          ),
                        )
                        : Text(
                          '⭐ ${rating.toStringAsFixed(1)} from $totalReviews reviews',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF54647A),
                          ),
                        ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 20,
                          color: Color(0xFF091426),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            address ?? '',
                            style: const TextStyle(color: Color(0xFF091426)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Color(0xFF091426),
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildVerificationCard(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 20.0, bottom: 10),
                          child: Text(
                            'Your Shop Gallery',
                            style: TextStyle(
                              color: Color(0xFF091426),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: shopPhotos.length + 1,
                            itemBuilder: (context, index) {
                              if (index == shopPhotos.length) {
                                return GestureDetector(
                                  onTap: _addShopPhoto,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.add_a_photo,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              }
                              final url = shopPhotos[index];
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child:
                                          url.startsWith('shimmer_')
                                              ? Shimmer.fromColors(
                                                baseColor: Colors.grey[700]!,
                                                highlightColor:
                                                    Colors.grey[500]!,
                                                child: Container(
                                                  height: 100,
                                                  width: 100,
                                                  margin: const EdgeInsets.only(
                                                    right: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              )
                                              : ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.network(
                                                  url,
                                                  height: 100,
                                                  width: 100,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    return _buildBrokenPhoto();
                                                  },
                                                  loadingBuilder: (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress ==
                                                        null) {
                                                      return child;
                                                    }
                                                    return Shimmer.fromColors(
                                                      baseColor:
                                                          Colors.grey[700]!,
                                                      highlightColor:
                                                          Colors.grey[500]!,
                                                      child: Container(
                                                        height: 100,
                                                        width: 100,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => _removeShopPhoto(index),
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black87,
                                        child: Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF091426),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          slideUpRoute(
                            GroomingMenuScreen(barberId: widget.barberId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.miscellaneous_services),
                      label: const Text('Manage Services'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,

                          slideUpRoute(
                            GroomingMenuScreen(barberId: widget.barberId),
                          ),
                        );
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildBrokenPhoto() {
    return Container(
      height: 100,
      width: 100,
      color: Colors.grey[850],
      child: const Icon(
        Icons.broken_image_outlined,
        color: Colors.white70,
        size: 32,
      ),
    );
  }

  Widget _buildVerificationCard() {
    final status = verificationStatus.toLowerCase();
    final isApproved = status == 'approved';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final color =
        isApproved
            ? const Color(0xFF00D084)
            : isPending
            ? Colors.orange
            : isRejected
            ? Colors.red
            : const Color(0xFF54647A);
    final title =
        isApproved
            ? 'Shop verified'
            : isPending
            ? 'Verification under review'
            : isRejected
            ? 'Verification rejected'
            : 'Verify your shop';
    final subtitle =
        isApproved
            ? 'Your shop can be shown to customers when subscription and live status are active.'
            : isPending
            ? 'We are reviewing your live shop photo and location.'
            : isRejected
            ? (verificationNote?.isNotEmpty == true
                ? verificationNote!
                : 'Capture a clear shop-front photo from your shop location and submit again.')
            : 'Capture a live shop photo with GPS to prevent fake shop listings.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApproved ? Icons.verified : Icons.storefront,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF54647A))),
          if (!isApproved) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF091426),
                  foregroundColor: Colors.white,
                ),
                onPressed:
                    isSubmittingVerification || isPending
                        ? null
                        : _submitShopVerification,
                icon:
                    isSubmittingVerification
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.camera_alt),
                label: Text(
                  isSubmittingVerification
                      ? 'Submitting...'
                      : isPending
                      ? 'Under review'
                      : isRejected
                      ? 'Submit again'
                      : 'Capture shop photo',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
