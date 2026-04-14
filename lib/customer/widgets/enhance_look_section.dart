import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/grooming_service.dart';
import '../../providers/booking_provider.dart';
import 'service_card.dart';

class EnhanceLookSection extends StatefulWidget {
  final String currentBookedService; // e.g., "Haircut"

  const EnhanceLookSection({
    super.key,
    required this.currentBookedService,
  });

  @override
  State<EnhanceLookSection> createState() => _EnhanceLookSectionState();
}

class _EnhanceLookSectionState extends State<EnhanceLookSection> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  final List<GroomingService> _allServices = _getDummyServices();
  
  // Dynamic Recommendation Logic
  final Map<String, List<String>> _recommendationMap = {
    "haircut": ["beard", "spa", "styling", "facial"],
    "beard": ["haircut", "facial", "massage"],
    "spa": ["massage", "facial", "styling"],
    "facial": ["massage", "spa", "beard"],
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  List<GroomingService> _getRecommendedServices() {
    final category = widget.currentBookedService.toLowerCase();
    final recommendedCategories = _recommendationMap[category] ?? ["haircut", "beard"];
    
    return _allServices.where((service) {
      return recommendedCategories.contains(service.category.toLowerCase()) && 
             service.name.toLowerCase() != category;
    }).toList();
  }

  GroomingService _generateDynamicCombo() {
    final category = widget.currentBookedService.toLowerCase();
    if (category.contains("haircut")) {
      return GroomingService(
        id: "combo_hair_beard",
        name: "Complete Look Combo",
        price: 299,
        duration: "45 mins",
        rating: 4.9,
        image: "",
        category: "combo",
        description: "Haircut + Beard Styling + Head Massage",
        isCombo: true,
        isRecommended: true,
      );
    } else {
      return GroomingService(
        id: "combo_fresh_face",
        name: "Fresh Face Combo",
        price: 399,
        duration: "60 mins",
        rating: 4.8,
        image: "",
        category: "combo",
        description: "Beard Trim + Charcoal Facial + Mask",
        isCombo: true,
        isRecommended: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendedServices = _getRecommendedServices();
    final combo = _generateDynamicCombo();
    final displayList = [combo, ...recommendedServices];

    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Enhance Your Look ✨",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "Recommended add-ons from your barber",
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                _buildTotalSummary(),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          SizedBox(
            height: 220,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                // Staggered Entry Animation
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(50 * (1 - value), 0),
                        child: ServiceCard(service: displayList[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummary() {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        if (provider.addedServices.isEmpty) return const SizedBox();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00D189).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00D189).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                "+${provider.addedServices.length} extras",
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00D189),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              Text(
                "₹${provider.totalAmount.toInt()}",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static List<GroomingService> _getDummyServices() {
    return [
      GroomingService(
        id: "s1",
        name: "Royal Beard Trim",
        price: 150,
        duration: "20 mins",
        rating: 4.8,
        image: "",
        category: "beard",
      ),
      GroomingService(
        id: "s2",
        name: "Charcoal Facial",
        price: 250,
        duration: "30 mins",
        rating: 4.7,
        image: "",
        category: "facial",
      ),
      GroomingService(
        id: "s3",
        name: "Head Massage",
        price: 100,
        duration: "15 mins",
        rating: 4.9,
        image: "",
        category: "spa",
      ),
      GroomingService(
        id: "s4",
        name: "Matte Hair Styling",
        price: 80,
        duration: "10 mins",
        rating: 4.6,
        image: "",
        category: "styling",
      ),
      GroomingService(
        id: "s5",
        name: "Classic Haircut",
        price: 200,
        duration: "30 mins",
        rating: 4.5,
        image: "",
        category: "hair",
      ),
    ];
  }
}
