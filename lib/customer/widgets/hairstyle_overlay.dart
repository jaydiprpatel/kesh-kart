import 'package:flutter/material.dart';

class HairstyleOverlay extends StatelessWidget {
  final String faceImagePath;
  final String hairImagePath;
  final double scale;

  const HairstyleOverlay({
    super.key,
    required this.faceImagePath,
    required this.hairImagePath,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: AspectRatio(
        aspectRatio: 1, // Photos were generated in square format
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Base Face Layer
            Image.asset(
              faceImagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.face, color: Colors.white24, size: 40),
              ),
            ),

            // Hairstyle Overlay Layer
            Image.asset(
              hairImagePath,
              fit: BoxFit.cover,
              // BlendMode.lighten or plus can help if PNG is black-background instead of transparent
              // colorBlendMode: BlendMode.screen, 
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
            
            // Subtle premium gradient overlay for lighting integration
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
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
    );
  }
}
