import 'package:flutter/material.dart';
import 'package:kesh_kart/login.dart';

/// Public entry point for the barber portal.
///
/// It provides a clear business journey before OTP authentication and keeps the
/// booking, shop-management, and subscription use cases reviewable on web.
class BarberWebLandingScreen extends StatelessWidget {
  const BarberWebLandingScreen({super.key});

  static const _ink = Color(0xFF091426);
  static const _coral = Color(0xFFE2613B);
  static const _muted = Color(0xFF58677C);

  void _openLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LogInScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 880;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 40 : 22,
                      wide ? 30 : 22,
                      wide ? 40 : 22,
                      32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _ink,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.content_cut_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KeshKart Barbers',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'Business tools for independent barbers',
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                              ],
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed:
                                  () =>
                                      Navigator.of(context).pushNamed('/terms'),
                              child: const Text('Terms'),
                            ),
                            const SizedBox(width: 4),
                            FilledButton(
                              onPressed: () => _openLogin(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: _ink,
                              ),
                              child: const Text('Sign in'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 52),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 6, child: _hero(context)),
                              const SizedBox(width: 46),
                              Expanded(flex: 5, child: _workflowCard()),
                            ],
                          )
                        else ...[
                          _hero(context),
                          const SizedBox(height: 28),
                          _workflowCard(),
                        ],
                        const SizedBox(height: 52),
                        const Text(
                          'Everything your shop needs, in one browser workspace',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, section) {
                            final columns =
                                section.maxWidth >= 900
                                    ? 3
                                    : section.maxWidth >= 560
                                    ? 2
                                    : 1;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: columns == 1 ? 2.5 : 1.45,
                              children: const [
                                _Feature(
                                  icon: Icons.calendar_month_rounded,
                                  title: 'Bookings & live queue',
                                  description:
                                      'View today’s appointments, check customers in, and complete services.',
                                ),
                                _Feature(
                                  icon: Icons.design_services_outlined,
                                  title: 'Services & availability',
                                  description:
                                      'Maintain your grooming menu and control when your shop accepts bookings.',
                                ),
                                _Feature(
                                  icon: Icons.workspace_premium_outlined,
                                  title: 'KeshKart Pro',
                                  description:
                                      'Choose a displayed plan and pay securely through Razorpay Standard Checkout.',
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 36),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE0E7F0)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 14,
                            children: [
                              const SizedBox(
                                width: 600,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ready to run your shop online?',
                                      style: TextStyle(
                                        color: _ink,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Sign in with your mobile number. New barbers can create a shop profile, add services, submit verification, and then manage operations on this website.',
                                      style: TextStyle(
                                        color: _muted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () => _openLogin(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _coral,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Create or access shop'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'KeshKart • Barber business portal',
                                style: TextStyle(color: _muted),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(
                                      context,
                                    ).pushNamed('/privacy'),
                                child: const Text('Privacy Policy'),
                              ),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(
                                      context,
                                    ).pushNamed('/terms'),
                                child: const Text('Terms & Conditions'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE7DC),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'FOR MODERN BARBER SHOPS',
            style: TextStyle(
              color: _coral,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Your barber business, organised from one place.',
          style: TextStyle(
            color: _ink,
            fontSize: 46,
            height: 1.04,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.7,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'KeshKart helps independent barbers set up a verified shop, manage daily bookings and queue activity, publish services, and subscribe to KeshKart Pro online.',
          style: TextStyle(color: _muted, fontSize: 16, height: 1.55),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: () => _openLogin(context),
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
              ),
              child: const Text('Open barber portal'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/terms'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
              ),
              child: const Text('View booking terms'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _workflowCard() {
    const steps = [
      (
        '1',
        'Create your business profile',
        'Add shop details, a storefront photo, and your live location.',
      ),
      (
        '2',
        'Submit shop verification',
        'Upload a current verification photo before opening bookings.',
      ),
      (
        '3',
        'Run and grow your shop',
        'Manage services, bookings, queue activity, and KeshKart Pro.',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.storefront_rounded,
            color: Color(0xFFFFC6AE),
            size: 32,
          ),
          const SizedBox(height: 16),
          const Text(
            'From setup to a bookable shop',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _coral,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      step.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.$3,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7DC),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFFE2613B)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF091426),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF58677C), height: 1.4),
          ),
        ],
      ),
    );
  }
}
