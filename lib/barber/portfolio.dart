import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:kesh_kart/backend/baas_client.dart';
import 'dart:ui';

class BarberPortfolioScreen extends StatefulWidget {
  final String barberId;
  const BarberPortfolioScreen({super.key, required this.barberId});

  @override
  State<BarberPortfolioScreen> createState() => _BarberPortfolioScreenState();
}

class _BarberPortfolioScreenState extends State<BarberPortfolioScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _portfolio = [];

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);
    try {
      final doc =
          await BaasClient.collection('users').doc(widget.barberId).get();
      final data = (doc as dynamic).data() as Map<String, dynamic>?;
      if (data != null) {
        final rawPortfolio = data['portfolio'] ?? [];
        setState(() {
          _portfolio =
              List<dynamic>.from(rawPortfolio).map((item) {
                if (item is String) {
                  return {'url': item, 'likes': 0};
                }
                return Map<String, dynamic>.from(item);
              }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading portfolio: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final fileName = path.basename(image.path);
      final ref = BaasClient.instance.sdk.storage.ref(
        'portfolio_images/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );
      final bytes = await image.readAsBytes();
      final storedFile = await ref.putBytes(bytes, contentType: 'image/jpeg');

      final newItem = {'url': storedFile.downloadUrl, 'likes': 0};
      _portfolio.insert(0, newItem);
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'portfolio': _portfolio});
      _loadPortfolio();
    } catch (e) {
      debugPrint("Error adding photo: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to upload photo")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePhoto(int index) async {
    setState(() => _isLoading = true);
    try {
      _portfolio.removeAt(index);
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'portfolio': _portfolio});
      _loadPortfolio();
    } catch (e) {
      debugPrint("Error deleting photo: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showFullScreenImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Center(
                child: InteractiveViewer(
                  child: Image.network(
                    _portfolio[index]['url'],
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("My Lookbook", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              )
              : _portfolio.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: _portfolio.length,
                itemBuilder: (context, index) {
                  final item = _portfolio[index];
                  return GestureDetector(
                    onTap: () => _showFullScreenImage(index),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              item['url'],
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white24,
                                    ),
                                  ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _deletePhoto(index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 5,
                                      sigmaY: 5,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      color: Colors.black.withOpacity(0.5),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Likes Count Badge
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 5,
                                      sigmaY: 5,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      color: Colors.black.withOpacity(0.4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.favorite,
                                            color: Colors.redAccent,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${item['likes'] ?? 0}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Gradient overlay for depth
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.2),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPhoto,
        backgroundColor: Colors.greenAccent,
        icon: const Icon(Icons.add_a_photo, color: Colors.black),
        label: const Text(
          "Add to Lookbook",
          style: TextStyle(color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            "Your lookbook is empty",
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add photos of your best haircuts to attract more customers!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
