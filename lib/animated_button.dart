import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedGradientButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;

  const AnimatedGradientButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  @override
  State<AnimatedGradientButton> createState() =>
      _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(); // Continuous animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: CircularGradientPainter(animationValue: _controller.value),
          child: Padding(
            padding: const EdgeInsets.all(4.0), // Space for gradient border
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Button background
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 50),
              ),
              onPressed: widget.onPressed,
              child: Text(
                widget.text,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CircularGradientPainter extends CustomPainter {
  final double animationValue;

  CircularGradientPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 4.0;
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Circular motion for gradient stops
    double angle = animationValue * 2 * pi;
    double x = 0.5 + 0.5 * cos(angle); // X moves in a circular path
    double y = 0.5 + 0.5 * sin(angle); // Y moves in a circular path

    Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, Colors.black], // Gradient colors
        begin: Alignment(x - 1, y - 1), // Start point moves in circular motion
        end: Alignment(x + 1, y + 1),   // End point follows circular motion
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    RRect rRect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      const Radius.circular(12),
    );

    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
