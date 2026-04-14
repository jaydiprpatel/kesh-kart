import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/models/hairstyle_preview.dart';
import 'package:kesh_kart/customer/widgets/hairstyle_overlay.dart';

class HairstylePreviewCard extends StatelessWidget {
  final HairstylePreview hairstyle;
  final String faceShape;
  final VoidCallback? onTap;

  const HairstylePreviewCard({
    super.key,
    required this.hairstyle,
    required this.faceShape,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine face shape folder name (lowercase)
    final faceFolder = faceShape.toLowerCase();
    
    // Construct paths for 3 angles
    final String faceFront = 'assets/faces/$faceFolder/front.png';
    final String faceLeft = 'assets/faces/$faceFolder/left.png';
    final String faceRight = 'assets/faces/$faceFolder/right.png';

    // Hairstyle paths (using the provided model's paths or relative convention)
    // We assume the model paths are structured relative to assets/hairstyles/{styleName}/...
    final String hairFront = hairstyle.frontImage;
    final String hairLeft = hairstyle.leftImage;
    final String hairRight = hairstyle.rightImage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D189).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-Angle View Section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left View (~45°)
                Expanded(
                  child: Opacity(
                    opacity: 0.6,
                    child: HairstyleOverlay(
                      faceImagePath: faceLeft,
                      hairImagePath: hairLeft,
                      scale: 0.8,
                    ),
                  ),
                ),
                
                // Center View (Front 0°) - Main Focus
                Expanded(
                  flex: 2,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D189).withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: HairstyleOverlay(
                            faceImagePath: faceFront,
                            hairImagePath: hairFront,
                            scale: 1.0,
                          ),
                        ),
                      ),
                      // "LIVE" Badge
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D189),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right View (~45°)
                Expanded(
                  child: Opacity(
                    opacity: 0.6,
                    child: HairstyleOverlay(
                      faceImagePath: faceRight,
                      hairImagePath: hairRight,
                      scale: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metadata Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hairstyle.name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D189).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Best for ${hairstyle.compatibleFaceShapes.contains(faceShape) ? "Your" : faceShape} Face',
                                style: const TextStyle(
                                  color: Color(0xFF00D189),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...hairstyle.tags.take(1).map((tag) => Text(
                              "#$tag",
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                            )),
                          ],
                        ),
                      ],
                    ),
                    // Match Percentage Column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(hairstyle.relevanceScore * 100).toInt()}%',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF00D189),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Match',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  hairstyle.description,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF222222),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Find Local Barbers', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
