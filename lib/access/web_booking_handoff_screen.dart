import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The mobile barber binary has no customer booking feature dependency.
class WebBookingHandoffScreen extends StatelessWidget {
  const WebBookingHandoffScreen({super.key});

  Future<void> _openBookingSite() async {
    await launchUrl(
      Uri.parse('https://keshkart.com'),
      mode: LaunchMode.externalApplication,
    );
  }

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
                const Icon(
                  Icons.language_rounded,
                  color: Color(0xFF091426),
                  size: 56,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Book on keshkart.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF091426),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The KeshKart Android app is for barbers. Book appointments in your browser instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5B6472), height: 1.45),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openBookingSite,
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: const Text('Open keshkart.com'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
