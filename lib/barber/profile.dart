import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/barber/service.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../login.dart';

class BarberProfileScreen extends StatefulWidget {
  final String barberId;
  const BarberProfileScreen({super.key, required this.barberId});

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  String? name;
  String? address;
  String? pincode;
  String? profileUrl;
  double? rating = 0.0;
  int? totalReviews = 0;
  List<String> shopPhotos = [];
  bool isUploading = false;
  bool isLoading = true;
  bool imageLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    debugPrint("DEBUG PROFILE: Loading profile for ID: ${widget.barberId}");
    if (widget.barberId.isEmpty) {
      debugPrint("DEBUG PROFILE: Error - barberId is empty!");
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final doc =
          await BaasClient.collection('users').doc(widget.barberId).get();

      debugPrint("DEBUG PROFILE: Doc exists? ${doc.exists}");

      if (doc.exists) {
        final data = doc.data()!;
        debugPrint('Barber Profile Data: $data');
        if (mounted) {
          setState(() {
            name = data['name'];
            address = data['shopAddress'];
            pincode = data['pincode']?.toString();
            profileUrl = data['profileUrl'];
            rating = data['averageRating']?.toDouble() ?? 0.0;
            totalReviews = data['totalReviews'] ?? 0;
            shopPhotos = List<String>.from(data['shopPhotos'] ?? []);
            isLoading = false;
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('barber_profile', doc.data().toString());
      } else {
        debugPrint("DEBUG PROFILE: Document does not exist!");
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("DEBUG PROFILE: Error loading profile: $e");
      if (mounted) setState(() => isLoading = false);
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
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'shopPhotos': shopPhotos});

      setState(() {});
    }
  }

  void _addShopPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // 👉 Add temporary shimmer placeholder
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() {
        shopPhotos.add('shimmer_$tempId'); // show shimmer
      });

      try {
        final uid = BaasClient.instance.sdk.auth.currentUser?.id ?? 'unknown';

        final filename = '${tempId}_$uid.jpg';
        String newUrl;

        // Custom BaaS Storage
        debugPrint("DEBUG: Uploading to Custom BaaS Storage...");
        final ref = BaasClient.instance.sdk.storage.ref(
          'shop_photos/$filename',
        );
        final bytes = await image.readAsBytes();
        final storedFile = await ref.putBytes(bytes, contentType: 'image/jpeg');
        newUrl = storedFile.downloadUrl;
        debugPrint("DEBUG: Upload Success. URL: $newUrl");

        // Replace shimmer placeholder with real image
        final index = shopPhotos.indexWhere((e) => e == 'shimmer_$tempId');
        if (index != -1) shopPhotos[index] = newUrl;

        await BaasClient.collection(
          'users',
        ).doc(widget.barberId).update({'shopPhotos': shopPhotos});

        setState(() {});
      } catch (e) {
        debugPrint('Upload failed: $e');
        // remove the placeholder shimmer if failed
        shopPhotos.removeWhere((e) => e.startsWith('shimmer_'));
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: name);
    final addressController = TextEditingController(text: address);
    final pincodeController = TextEditingController(text: pincode);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Edit Profile',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Name / Shop Name',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Shop Address',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pincodeController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pincode',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final newAddress = addressController.text.trim();
                  final newPincode =
                      pincodeController.text.trim(); // Get new pincode

                  if (newName.isEmpty || newAddress.isEmpty) return;

                  Navigator.pop(context);
                  setState(() => isLoading = true);

                  try {
                    await BaasClient.collection(
                      'users',
                    ).doc(widget.barberId).update({
                      // Changed to update method
                      'name': newName,
                      'shopAddress': newAddress,
                      'pincode': newPincode, // Added pincode to update
                      'updatedAt': DateTime.now().toIso8601String(),
                    });

                    setState(() {
                      name = newName;
                      address = newAddress;
                      pincode = newPincode; // Update local state
                      isLoading = false;
                    });
                  } catch (e) {
                    debugPrint("Error saving profile: $e");
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _logout() async {
    final confirmed = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Logout Confirmation',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to logout from Kesh Kart?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      if (mounted) setState(() => isLoading = true);

      try {
        // 1. Clear Local Storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // 2. Sign out
        await BaasClient.instance.sdk.auth.signOut();

        // 3. Navigate to Login (Remove all history)
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LogInScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint("Logout error: $e");
        if (mounted) setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Your Profile"),
        backgroundColor: Colors.black,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    totalReviews == 0
                        ? const Text(
                          '⭐ No reviews yet — your experience matters!',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        )
                        : Text(
                          '⭐ ${rating?.toStringAsFixed(1)} from $totalReviews reviews',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            "${address ?? ''}${(pincode != null && pincode!.isNotEmpty && !(address ?? '').contains(pincode!)) ? ', $pincode' : ''}",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.white,
                          ),
                          onPressed: _showEditDialog,
                        ),
                      ],
                    ),
                    if (shopPhotos.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 20.0, bottom: 10),
                            child: Text(
                              'Your Shop Gallery',
                              style: TextStyle(
                                color: Colors.white,
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
                                                    margin:
                                                        const EdgeInsets.only(
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
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
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
                      onPressed: _logout,
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
}
