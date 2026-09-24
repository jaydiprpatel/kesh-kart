import 'package:flutter/material.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/login.dart';

/// The web portal is for an approved barber account, not public onboarding.
/// New-barber identity and shop verification remain on the Android app.
class BarberWebRegistrationNotice extends StatelessWidget {
  const BarberWebRegistrationNotice({super.key});

  Future<void> _signOut(BuildContext context) async {
    await BedrockClient.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LogInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
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
                    Icons.verified_user_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Set up your barber account in the KeshKart Android app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF091426),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Shop registration and verification are completed in the barber app. Once approved, return here to manage your bookings from a browser.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5B6472), height: 1.45),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Use another account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
