import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/models/hairstyle_preview.dart';
import 'package:kesh_kart/repositories/hairstyle_preview_repository.dart';
import 'package:kesh_kart/customer/widgets/hairstyle_preview_card.dart';

class AiStylerScreen extends StatefulWidget {
  final String? initialFaceShape;

  const AiStylerScreen({super.key, this.initialFaceShape});

  @override
  State<AiStylerScreen> createState() => _AiStylerScreenState();
}

class _AiStylerScreenState extends State<AiStylerScreen> {
  late String _selectedFaceShape;
  final List<String> _faceShapes = ['Oval', 'Round', 'Square', 'Heart', 'Diamond'];
  late PageController _pageController;
  List<HairstylePreview> _styles = [];

  @override
  void initState() {
    super.initState();
    _selectedFaceShape = widget.initialFaceShape ?? 'Oval';
    _pageController = PageController(viewportFraction: 0.9);
    _loadStyles();
  }

  void _loadStyles() {
    setState(() {
      _styles = HairstylePreviewRepository.filterByFaceShape(_selectedFaceShape);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'AI STYLER',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Face Shape Selector
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _faceShapes.length,
              itemBuilder: (context, index) {
                final shape = _faceShapes[index];
                final isSelected = _selectedFaceShape == shape;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFaceShape = shape;
                      _loadStyles();
                      _pageController.jumpToPage(0);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00D189) : Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00D189) : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      shape,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Carousel
          Expanded(
            child: _styles.isEmpty
                ? const Center(child: Text("No styles matched for this face shape.", style: TextStyle(color: Colors.white54)))
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _styles.length,
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 1.0;
                          if (_pageController.position.haveDimensions) {
                            value = (_pageController.page! - index);
                            value = (1 - (value.abs() * 0.1)).clamp(0.0, 1.0);
                          }
                          return Transform.scale(
                            scale: Curves.easeInOut.transform(value),
                            child: Opacity(
                              opacity: Curves.easeInOut.transform(value),
                              child: child,
                            ),
                          );
                        },
                        child: HairstylePreviewCard(
                          hairstyle: _styles[index],
                          faceShape: _selectedFaceShape,
                          onTap: () {
                            // Link to barber finder in a real app
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Finding barbers for ${_styles[index].name}...')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Footer indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_styles.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
