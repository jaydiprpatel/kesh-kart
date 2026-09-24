import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Keeps browser pages comfortably readable on a wide screen without changing
/// the phone layout used by the Android app.
class KeshKartDesktopFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const KeshKartDesktopFrame({
    super.key,
    required this.child,
    this.maxWidth = 1120,
  });

  static bool isWide(BuildContext context) =>
      kIsWeb && MediaQuery.sizeOf(context).width >= 900;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            constraints.maxWidth > maxWidth ? maxWidth : constraints.maxWidth;

        return ColoredBox(
          color: const Color(0xFFF0F4F8),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
