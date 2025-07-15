import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kesh_kart/barber/service.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

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
  double? rating;
  int? totalReviews;
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
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.barberId)
            .get();
    if (doc.exists) {
      final data = doc.data()!;
      debugPrint('Barber Profile: $data');
      setState(() {
        name = data['name'];
        address = data['shopAddress'];
        profileUrl = data['profileUrl'];
        rating = data['averageRating']?.toDouble() ?? 0.0;
        totalReviews = data['totalReviews'] ?? 0;
        shopPhotos = List<String>.from(data['shopPhotos'] ?? []);
        isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('barber_profile', doc.data().toString());
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.barberId)
          .update({'shopPhotos': shopPhotos});

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
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final filename = '$tempId\_$uid.jpg';

        final ref = FirebaseStorage.instance
            .ref()
            .child('shop_photos')
            .child(filename);

        await ref.putFile(File(image.path));
        final newUrl = await ref.getDownloadURL();

        // Replace shimmer placeholder with real image
        final index = shopPhotos.indexWhere((e) => e == 'shimmer_$tempId');
        if (index != -1) shopPhotos[index] = newUrl;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.barberId)
            .update({'shopPhotos': shopPhotos});

        setState(() {});
      } catch (e) {
        debugPrint('Upload failed: $e');
        // remove the placeholder shimmer if failed
        shopPhotos.removeWhere((e) => e.startsWith('shimmer_'));
        setState(() {});
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
                            address ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.white,
                          ),
                          onPressed: () {},
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
}
