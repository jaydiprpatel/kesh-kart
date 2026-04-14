import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/models/hairstyle.dart';
import 'dart:ui';

class HairstyleDetailsScreen extends StatelessWidget {
  final Hairstyle hairstyle;

  const HairstyleDetailsScreen({super.key, required this.hairstyle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildDescription(),
                  const SizedBox(height: 32),
                  _buildAttributesGrid(),
                  const SizedBox(height: 40),
                  _buildActionButtons(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 450,
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            hairstyle.coverImage.startsWith('assets/')
                ? Image.asset(hairstyle.coverImage, fit: BoxFit.cover)
                : Image.network(
                  hairstyle.coverImage.isNotEmpty
                      ? hairstyle.coverImage
                      : 'https://via.placeholder.com/800',
                  fit: BoxFit.cover,
                ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.3), Colors.black],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                hairstyle.name,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_border, color: Color(0xFF00D189)),
              onPressed: () {
                // TODO: Implement save logic
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: hairstyle.purposes.map((p) => _buildPurposeTag(p)).toList(),
        ),
      ],
    );
  }

  Widget _buildPurposeTag(String purpose) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF00D189).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D189).withOpacity(0.3)),
      ),
      child: Text(
        purpose[0].toUpperCase() + purpose.substring(1),
        style: GoogleFonts.poppins(
          color: const Color(0xFF00D189),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "About this style",
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hairstyle.description,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildAttributesGrid() {
    return Row(
      children: [
        _buildAttributeItem(Icons.height, "Hair Length", hairstyle.hairLength),
        const Spacer(),
        _buildAttributeItem(
          Icons.face_retouching_natural,
          "Beard Ready",
          hairstyle.beardCompatible ? "Yes" : "No",
        ),
        const Spacer(),
        _buildAttributeItem(
          Icons.settings_suggest,
          "Maintenance",
          hairstyle.maintenance,
        ),
      ],
    );
  }

  Widget _buildAttributeItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00D189), size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value[0].toUpperCase() + value.substring(1).replaceAll('_', ' '),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildPrimaryButton(
          "Book this style",
          onPressed: () {
            // TODO: Connect to booking flow
          },
        ),
        const SizedBox(height: 16),
        _buildSecondaryButton(
          "Try with AI",
          icon: Icons.auto_awesome,
          onPressed: () {
            // Future AI implementation
          },
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, {required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D189),
          shape: RoundedRectangle_circular(16),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    String text, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF00D189)),
          shape: RoundedRectangle_circular(16),
        ),
        icon: Icon(icon, color: const Color(0xFF00D189)),
        label: Text(
          text,
          style: GoogleFonts.poppins(
            color: const Color(0xFF00D189),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  RoundedRectangleBorder RoundedRectangle_circular(double radius) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }
}
