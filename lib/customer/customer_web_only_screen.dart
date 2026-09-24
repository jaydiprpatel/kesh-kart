import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerWebOnlyScreen extends StatelessWidget {
  const CustomerWebOnlyScreen({super.key});

  static final Uri _customerWebUrl = Uri.parse('https://keshkart.com');

  Future<void> _openCustomerWeb(BuildContext context) async {
    final opened = await launchUrl(
      _customerWebUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open keshkart.com in your browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 62,
                    color: Color(0xFF091426),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Book on the web',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF091426),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'KeshKart customer booking, receipts, and calendar reminders now live at keshkart.com. This mobile app is for barbers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF54647A), height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openCustomerWeb(context),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open keshkart.com'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF091426),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
