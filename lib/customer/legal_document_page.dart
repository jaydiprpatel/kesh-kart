import 'package:flutter/material.dart';

enum LegalDocument { privacy, terms }

class LegalDocumentPage extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentPage({super.key, required this.document});

  static const _ink = Color(0xFF091426);
  static const _muted = Color(0xFF54647A);
  static const _coral = Color(0xFFE2613B);

  String get _title =>
      document == LegalDocument.privacy
          ? 'Privacy Policy'
          : 'Terms & Conditions';

  List<_LegalSection> get _sections =>
      document == LegalDocument.privacy ? _privacySections : _termsSections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _ink,
        elevation: 0,
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Last updated: 7 September 2026',
                        style: TextStyle(color: Color(0xFFD6DFEC)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'KeshKart is operated by DVSP Tech. Please read this document before using the customer booking service.',
                  style: TextStyle(color: _muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                ..._sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _LegalSectionCard(section: section),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _coral.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Questions or a privacy request? Contact KeshKart support from the customer app or website and include the mobile number used for your booking. Do not send OTPs or payment credentials to support.',
                    style: TextStyle(color: _ink, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _privacySections = <_LegalSection>[
    _LegalSection(
      '1. Information we collect',
      'We collect the information needed to create and manage a booking: your mobile number, name, booking time, selected barber or shop, and any information you choose to provide. If you choose to use nearby-barber features, we process your location after you grant permission. We also retain security and service logs needed to prevent abuse and keep the service reliable.',
    ),
    _LegalSection(
      '2. How we use information',
      'We use your information to authenticate your account, show relevant barbers, create and manage appointments, issue booking receipts and QR check-in records, provide customer support, and protect KeshKart from fraud or misuse. We use a reminder preference only to provide the reminder channel you select.',
    ),
    _LegalSection(
      '3. Booking communications',
      'A calendar receipt is available after a booking. Email, WhatsApp, or SMS reminders are sent only when you select that channel and KeshKart has enabled an approved provider. Carrier or provider charges may apply to messages you receive. You can select no direct reminder for a booking.',
    ),
    _LegalSection(
      '4. When information is shared',
      'We share the booking details reasonably needed to fulfil your appointment with the selected barber or shop. We may use carefully selected service providers for hosting, authentication, communications, security, and support. We do not sell personal information.',
    ),
    _LegalSection(
      '5. Retention, choices, and requests',
      'We keep information only for as long as needed for bookings, support, security, dispute handling, and legal obligations. You may ask to access, correct, or delete your personal information through KeshKart support. Deletion requests are subject to records we must retain by law or for legitimate security and dispute purposes.',
    ),
    _LegalSection(
      '6. Security and updates',
      'We use reasonable technical and organisational safeguards, but no internet service can guarantee absolute security. Keep your OTP private. We may update this policy when the service or legal requirements change; the current version is published on KeshKart before it applies.',
    ),
  ];

  static const _termsSections = <_LegalSection>[
    _LegalSection(
      '1. KeshKart booking service',
      'KeshKart helps customers discover barber shops and request appointments. The barber or shop independently provides the grooming service. Shop availability, service descriptions, prices, hygiene practices, and the final service outcome remain the responsibility of that barber or shop.',
    ),
    _LegalSection(
      '2. Your booking',
      'A booking is confirmed only when KeshKart shows a booking receipt or reference. Please provide accurate information and arrive at the booked time. Your QR receipt is a booking/check-in reference; it is not a payment receipt unless KeshKart clearly states otherwise.',
    ),
    _LegalSection(
      '3. Changes, cancellation, and no-shows',
      'Use the booking controls or contact the barber or shop promptly if you need to change or cancel. Any cancellation, rescheduling, late-arrival, or no-show rule shown for the booking or communicated by the barber or shop applies to that appointment. KeshKart does not promise a refund, credit, or a particular service outcome unless it expressly says so in writing.',
    ),
    _LegalSection(
      '4. Fair and safe use',
      'Do not use another person’s account, submit false booking details, misuse a QR receipt, interfere with the service, or behave abusively toward customers, barbers, or support. We may restrict access where necessary to protect people, bookings, or the platform.',
    ),
    _LegalSection(
      '5. Communications and support',
      'By booking, you agree that KeshKart may send essential service messages about that booking. Optional direct reminders follow your selected preference. For a booking issue, first contact the barber or shop where appropriate and then contact KeshKart support with your booking reference.',
    ),
    _LegalSection(
      '6. Changes to these terms',
      'We may update these terms to reflect service, operational, or legal changes. The updated version will be posted on KeshKart with its effective date. Continued use after that date means you accept the updated terms to the extent permitted by law.',
    ),
  ];
}

class _LegalSectionCard extends StatelessWidget {
  final _LegalSection section;

  const _LegalSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E3E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              color: Color(0xFF091426),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            section.body,
            style: const TextStyle(color: Color(0xFF45474C), height: 1.52),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String body;

  const _LegalSection(this.title, this.body);
}
