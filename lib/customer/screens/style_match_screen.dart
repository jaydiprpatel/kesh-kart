import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/customer/widgets/loading_placeholders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/features/face_scan/face_scan_screen.dart';
import 'package:kesh_kart/customer/screens/ai_styler_screen.dart';

class StyleMatchScreen extends StatefulWidget {
  const StyleMatchScreen({super.key});

  @override
  State<StyleMatchScreen> createState() => _StyleMatchScreenState();
}

class _StyleMatchScreenState extends State<StyleMatchScreen> {
  int _currentStep = 0;

  String? _selectedFaceShape;
  String? _selectedHairType;
  String? _selectedHairDensity;

  bool _isLoading = false;
  String? _userId;

  final List<String> _faceShapes = ['Round', 'Oval', 'Square', 'Heart'];
  final List<String> _hairTypes = ['Straight', 'Wavy', 'Curly'];
  final List<String> _hairDensities = ['Thin', 'Normal', 'Thick'];

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
    });
  }

  Future<void> _saveProfileData() async {
    if (_userId == null) return;
    try {
      final updates = <String, dynamic>{};
      if (_selectedFaceShape != null) updates['faceShape'] = _selectedFaceShape;
      if (_selectedHairType != null) updates['hairType'] = _selectedHairType;
      if (_selectedHairDensity != null) {
        updates['hairDensity'] = _selectedHairDensity;
      }

      if (updates.isNotEmpty) {
        updates['styleMatchCompleted'] = true;
        updates['updatedAt'] = DateTime.now().toIso8601String();

        // Use update first, fallback to set if document doesn't exist (Guest case)
        try {
          await BaasClient.collection('users').doc(_userId!).update(updates);
          debugPrint("[SUCCESS] Profile fields updated for $_userId: $updates");
        } catch (e) {
          await BaasClient.collection('users').doc(_userId!).set(updates);
          debugPrint(
            "[SUCCESS] Profile document created for $_userId: $updates",
          );
        }
      }
    } catch (e) {
      debugPrint("[ERROR] Profile update failed for $_userId: $e");
    }
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
    if (_currentStep == 3) {
      _fetchStyles();
    }
  }

  Future<void> _fetchStyles() async {
    setState(() {
      _isLoading = true;
    });

    await _saveProfileData();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AiStylerScreen(initialFaceShape: _selectedFaceShape),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Style Match',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading ? _buildLoadingState() : _buildQuestionnaire(),
    );
  }

  Widget _buildQuestionnaire() {
    String title = '';
    List<String> options = [];
    String? selectedValue;
    Function(String) onSelect;

    if (_currentStep == 0) {
      title = 'Select your Face Shape';
      options = _faceShapes;
      selectedValue = _selectedFaceShape;
      onSelect = (val) {
        setState(() => _selectedFaceShape = val);
        _saveProfileData(); // Save immediately
      };
    } else if (_currentStep == 1) {
      title = 'Select your Hair Type';
      options = _hairTypes;
      selectedValue = _selectedHairType;
      onSelect = (val) {
        setState(() => _selectedHairType = val);
        _saveProfileData(); // Save immediately
      };
    } else {
      title = 'Select your Hair Density';
      options = _hairDensities;
      selectedValue = _selectedHairDensity;
      onSelect = (val) {
        setState(() => _selectedHairDensity = val);
        _saveProfileData(); // Save immediately
      };
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 40),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This helps us find the best styles for you.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (_currentStep == 0 && _selectedFaceShape == null) _buildScanCTA(),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = selectedValue == option;
                return GestureDetector(
                  onTap: () => onSelect(option),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? const Color(0xFF00D189).withOpacity(0.1)
                              : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFF00D189)
                                : Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          option,
                          style: GoogleFonts.poppins(
                            color:
                                isSelected
                                    ? const Color(0xFF00D189)
                                    : Colors.white,
                            fontSize: 18,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF00D189),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: selectedValue != null ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D189),
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _currentStep == 2 ? 'Find My Styles' : 'Next',
                style: GoogleFonts.poppins(
                  color: selectedValue != null ? Colors.black : Colors.white24,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCTA() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const FaceScanScreen()),
        );
        if (result != null) {
          setState(() {
            _selectedFaceShape = result;
          });
          // Automatically proceed to fetch styles if user just scanned their face
          // (assuming defaults for hair type and density are acceptable)
          // `_fetchStyles()` will also implicitly call `_saveProfileData()` for us.
          _fetchStyles();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF00D189).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00D189).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D189),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.face_retouching_natural,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not sure about your face shape?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Scan my face',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF00D189),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF00D189),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
            decoration: BoxDecoration(
              color:
                  index <= _currentStep
                      ? const Color(0xFF00D189)
                      : Colors.white10,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Finding perfect styles for you...',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.55,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => const StyleCardSkeleton(),
          ),
        ),
      ],
    );
  }
}
