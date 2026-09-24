import 'package:flutter/material.dart';

/// Shown when a barber opens the customer web experience.
class BarberMobileOnlyScreen extends StatelessWidget {
  const BarberMobileOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF091426),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.content_cut_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'KeshKart for barbers lives in the mobile app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF091426),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use the KeshKart Barber app to manage bookings and scan customer receipts at check-in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5B6472), height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
