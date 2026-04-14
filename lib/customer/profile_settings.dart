import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kesh_kart/login.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CustomerProfileSettings extends StatefulWidget {
  const CustomerProfileSettings({super.key});

  @override
  State<CustomerProfileSettings> createState() =>
      _CustomerProfileSettingsState();
}

class _CustomerProfileSettingsState extends State<CustomerProfileSettings> {
  final _nameController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _isLoading = false;
  String _userId = '';
  String _email = '';
  String? _profilePhotoUrl;
  bool _isImageLoading = false;

  String _hairType = "Straight";
  String _preferredStyle = "Fade";
  String _skinType = "Normal";
  String _faceShape = "Oval";

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId') ?? '';
      _nameController.text = prefs.getString('barberName') ?? 'User';
      _pincodeController.text = prefs.getString('userPincode') ?? '';
      _email = prefs.getString('email') ?? '';
    });

    try {
      final doc = await BaasClient.collection('users').doc(_userId).get();
      final data = (doc as dynamic).data() as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _hairType = data['hairType'] ?? "Straight";
          _preferredStyle = data['preferredStyle'] ?? "Fade";
          _skinType = data['skinType'] ?? "Normal";
          _faceShape = data['faceShape'] ?? "Oval";
          _profilePhotoUrl = data['profilePhoto'];
        });
      }
    } catch (e) {
      debugPrint("Error loading profile data: $e");
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _pincodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name and Pincode cannot be empty")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      bool isFilled(String? s) {
        if (s == null) return false;
        String val = s.trim().toLowerCase();
        return val.isNotEmpty && val != 'not set' && val != 'unset' && val != 'unknown' && val != 'guest';
      }

      final bool profileComplete =
          isFilled(_hairType) &&
          isFilled(_preferredStyle) &&
          isFilled(_skinType) &&
          isFilled(_faceShape);
      final Map<String, dynamic> profileData = {
        'name': _nameController.text.trim(),
        'pincode':
            int.tryParse(_pincodeController.text.trim()) ??
            _pincodeController.text.trim(),
        'hairType': _hairType,
        'preferredStyle': _preferredStyle,
        'skinType': _skinType,
        'faceShape': _faceShape,
        'profileCompleted': profileComplete,
        'profilePhoto': _profilePhotoUrl,
      };

      // Update DB with fallback for new documents
      try {
        await BaasClient.collection('users').doc(_userId).update(profileData);
      } catch (e) {
        // Document might not exist (Guest case)
        final Map<String, dynamic> guestData = {
          'name': _nameController.text.trim(),
          'pincode':
              int.tryParse(_pincodeController.text.trim()) ??
              _pincodeController.text.trim(),
          'phone': prefs.getString(
            'userPhone',
          ), // Critical link for identity recovery
          'hairType': _hairType,
          'preferredStyle': _preferredStyle,
          'skinType': _skinType,
          'faceShape': _faceShape,
          'profileCompleted': profileComplete,
          'profilePhoto': _profilePhotoUrl,
        };
        await BaasClient.collection('users').doc(_userId).set(guestData);
      }

      // Update Local Prefs
      await prefs.setString('barberName', _nameController.text.trim());
      await prefs.setString('userPincode', _pincodeController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _uploadProfilePicture(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _uploadProfilePicture(File file) async {
    if (_userId.isEmpty) return;

    setState(() => _isImageLoading = true);
    try {
      final storage = BaasClient.instance.sdk.storage;
      final ref = storage.ref('profiles/$_userId.jpg');
      
      final storedFile = await ref.putFile(file, contentType: 'image/jpeg');
      
      setState(() {
        _profilePhotoUrl = storedFile.downloadUrl;
        _isImageLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded! Tap Save to persist.')),
        );
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      setState(() => _isImageLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Profile Settings",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              try {
                await BaasClient.instance.sdk.auth.signOut();
              } catch (_) {}
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LogInScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isImageLoading ? null : _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white12,
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      clipBehavior: Clip.antiAlias,
                      child:
                          _isImageLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00D189),
                                ),
                              )
                              : Image.network(
                                _profilePhotoUrl ??
                                    'https://ui-avatars.com/api/?name=${_nameController.text}&background=00D189&color=fff',
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      color: Colors.white12,
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white54,
                                        size: 40,
                                      ),
                                    ),
                              ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFF00D189),
                        child: Icon(
                          _isImageLoading ? Icons.hourglass_top : Icons.camera_alt,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField("Full Name", _nameController, Icons.person),
            const SizedBox(height: 16),
            _buildTextField(
              "Email",
              TextEditingController(text: _email),
              Icons.email,
              enabled: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "Default Pincode",
              _pincodeController,
              Icons.location_on,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            _buildPreferencesSection(),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D189),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "Save Changes",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Personal Preferences",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildPreferenceTile(
          "Hair Type",
          ["Straight", "Curly", "Wavy", "Coily"],
          _hairType,
          (val) => setState(() => _hairType = val),
        ),
        const SizedBox(height: 16),
        _buildPreferenceTile(
          "Preferred Style",
          ["Fade", "Buzz Cut", "Long", "Classic"],
          _preferredStyle,
          (val) => setState(() => _preferredStyle = val),
        ),
        const SizedBox(height: 16),
        _buildPreferenceTile(
          "Skin Type",
          ["Normal", "Dry", "Oily", "Sensitive"],
          _skinType,
          (val) => setState(() => _skinType = val),
        ),
        const SizedBox(height: 16),
        _buildPreferenceTile(
          "Face Shape",
          ["Round", "Oval", "Square", "Heart", "Diamond"],
          _faceShape,
          (val) => setState(() => _faceShape = val),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile(
    String title,
    List<String> options,
    String current,
    Function(String) onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              options.map((opt) {
                final isSelected = current == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onSelected(opt);
                  },
                  selectedColor: const Color(0xFF00D189),
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white54, size: 20),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
