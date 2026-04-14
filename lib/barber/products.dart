import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:kesh_kart/backend/baas_client.dart';

class BarberProductsScreen extends StatefulWidget {
  final String barberId;
  const BarberProductsScreen({super.key, required this.barberId});

  @override
  State<BarberProductsScreen> createState() => _BarberProductsScreenState();
}

class _BarberProductsScreenState extends State<BarberProductsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _productsList = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final doc =
          await BaasClient.collection('users').doc(widget.barberId).get();
      final data = (doc as dynamic).data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('products')) {
        setState(() {
          _productsList = List<Map<String, dynamic>>.from(data['products']);
        });
      }
    } catch (e) {
      debugPrint("Error loading products: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProducts() async {
    setState(() => _isLoading = true);
    try {
      debugPrint("💾 Saving products to BaaS: $_productsList");
      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'products': _productsList});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Products updated successfully')),
      );
    } catch (e) {
      debugPrint("Error saving products: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update products')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editProduct(int? index) {
    final isNew = index == null;
    final Map<String, dynamic> product =
        isNew
            ? {
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'name': '',
              'price': '',
              'description': '',
              'inStock': true,
              'imageUrl': '',
            }
            : Map<String, dynamic>.from(_productsList[index]);

    final _nameController = TextEditingController(text: product['name']);
    final _priceController = TextEditingController(
      text: product['price'].toString(),
    );
    final _descController = TextEditingController(text: product['description']);

    // Using a local variable for the image file if picked
    bool isUploading = false;
    String imageUrl =
        product['imageUrl']?.toString().isNotEmpty == true
            ? product['imageUrl']
            : "https://via.placeholder.com/150";

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental close during upload
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> _pickAndUpload() async {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                );
                if (image != null) {
                  setDialogState(() => isUploading = true);
                  try {
                    final fileName = path.basename(image.path);
                    final ref = BaasClient.instance.sdk.storage.ref(
                      'product_images/${DateTime.now().millisecondsSinceEpoch}_$fileName',
                    );
                    final bytes = await image.readAsBytes();
                    final storedFile = await ref.putBytes(
                      bytes,
                      contentType: 'image/jpeg',
                    );
                    setDialogState(() {
                      imageUrl = storedFile.downloadUrl;
                      product['imageUrl'] = imageUrl;
                      isUploading = false;
                    });
                  } catch (e) {
                    debugPrint("Error uploading image: $e");
                    setDialogState(() => isUploading = false);
                  }
                }
              }

              return AlertDialog(
                backgroundColor: Colors.grey[900],
                title: Text(
                  isNew ? 'Add Product' : 'Edit Product',
                  style: const TextStyle(color: Colors.white),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : _pickAndUpload,
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background image or placeholder
                              if (imageUrl.isNotEmpty &&
                                  !imageUrl.contains("placeholder"))
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.white24,
                                              size: 40,
                                            ),
                                  ),
                                ),

                              if (imageUrl.isEmpty ||
                                  imageUrl.contains("placeholder"))
                                const Icon(
                                  Icons.add_a_photo,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              if (isUploading)
                                const CircularProgressIndicator(
                                  color: Colors.greenAccent,
                                ),
                              if (!isUploading)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Product Name',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white10,
                        ),
                        enabled: !isUploading,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _priceController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Price',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white10,
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white10,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text(
                          "In Stock",
                          style: TextStyle(color: Colors.white),
                        ),
                        value: product['inStock'] ?? true,
                        activeColor: Colors.greenAccent,
                        onChanged: (val) {
                          setDialogState(() {
                            product['inStock'] = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isUploading
                            ? null
                            : () {
                              final name = _nameController.text.trim();
                              final price = _priceController.text.trim();
                              if (name.isEmpty || price.isEmpty) {
                                return;
                              }

                              product['name'] = name;
                              product['price'] = price;
                              product['description'] =
                                  _descController.text.trim();

                              // Final check to ensure imageUrl is present
                              if (product['imageUrl'] == null ||
                                  product['imageUrl'].toString().isEmpty) {
                                product['imageUrl'] =
                                    "https://via.placeholder.com/150?text=Product";
                              }

                              setState(() {
                                if (isNew) {
                                  _productsList.add(product);
                                } else {
                                  _productsList[index] = product;
                                }
                              });
                              _saveProducts();
                              Navigator.pop(context);
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _deleteProduct(int index) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              "Delete Product?",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "This cannot be undone.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _productsList.removeAt(index);
                  });
                  _saveProducts();
                  Navigator.pop(ctx);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Manage Products",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              )
              : _productsList.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _productsList.length,
                itemBuilder: (context, index) {
                  final product = _productsList[index];
                  return GestureDetector(
                    onTap: () => _editProduct(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    product['imageUrl'] ??
                                        "https://via.placeholder.com/150",
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  if (!(product['inStock'] ?? true))
                                    Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Text(
                                          "OUT OF STOCK",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => _deleteProduct(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'] ?? 'Product',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "₹${product['price']}",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProduct(null),
        backgroundColor: Colors.greenAccent,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Add Product", style: TextStyle(color: Colors.black)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            "No products listed yet",
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add shampoos, gels, or accessories to sell!",
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
