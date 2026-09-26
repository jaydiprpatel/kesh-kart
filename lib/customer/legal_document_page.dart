import 'package:flutter/material.dart';

enum LegalDocument { privacy, terms }

enum LegalAudience { customer, barber }

class LegalDocumentPage extends StatelessWidget {
  final LegalDocument document;
  final LegalAudience audience;

  const LegalDocumentPage({
    super.key,
    required this.document,
    this.audience = LegalAudience.customer,
  });

  static const _ink = Color(0xFF091426);
  static const _muted = Color(0xFF54647A);
  static const _coral = Color(0xFFE2613B);

  String get _title =>
      document == LegalDocument.privacy
          ? 'Privacy Policy'
          : audience == LegalAudience.barber
          ? 'Barber Terms & Conditions'
          : 'Customer Terms & Conditions';

  List<_LegalSection> get _sections =>
      document == LegalDocument.privacy
          ? _privacySections
          : audience == LegalAudience.barber
          ? _barberTermsSections
          : _customerTermsSections;

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
                  'KeshKart is operated by DVSP Tech. Please read this document before using the service.',
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

  static const _customerTermsSections = <_LegalSection>[
    _LegalSection(
      '1. KeshKart booking service',
      'KeshKart helps customers discover barber shops and request appointments. The barber or shop independently provides the grooming service. Shop availability, service descriptions, prices, hygiene practices, and the final service outcome remain the responsibility of that barber or shop.',
    ),
    _LegalSection(
      '2. Your booking',
      'A booking is confirmed only when KeshKart shows a booking receipt or reference. Please provide accurate information and arrive at the booked time. Your QR receipt is a booking/check-in reference; it is not a payment receipt unless KeshKart clearly states otherwise. Unless a booking clearly states otherwise, pay the barber or shop directly when you visit; KeshKart does not collect the service payment.',
    ),
    _LegalSection(
      '3. Changes, cancellation, and no-shows',
      'Use the booking controls or contact the barber or shop promptly if you need to change or cancel. Any cancellation, rescheduling, late-arrival, or no-show rule shown for the booking or communicated by the barber or shop applies to that appointment. Repeated cancellations, rescheduling, no-shows, or misuse may lead to booking limits, suspension, or removal from KeshKart after review. KeshKart does not promise a refund, credit, or a particular service outcome unless it expressly says so in writing.',
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

  static const _barberTermsSections = <_LegalSection>[
    _LegalSection(
      '1. Your independent shop',
      'You operate your shop independently. You are responsible for the quality, safety, hygiene, legality, availability, staff, prices, service descriptions, duration estimates, and outcome of every service you offer. KeshKart provides discovery, booking, queue, and communication tools; it does not provide the grooming service.',
    ),
    _LegalSection(
      '2. Bookings and customer care',
      'Keep your opening status, seats, services, prices, duration, and availability accurate. Honour confirmed appointments where reasonably possible, communicate changes promptly, and handle cancellations, rescheduling, late arrivals, no-shows, complaints, and refunds fairly and in accordance with applicable law and your displayed shop rules.',
    ),
    _LegalSection(
      '3. Payments',
      'Unless KeshKart expressly enables a different payment flow, you collect the service payment directly from the customer at the shop. You must clearly communicate the final payable amount and any permitted charges before providing the service. Do not represent KeshKart as the merchant for your independently provided services.',
    ),
    _LegalSection(
      '4. Platform conduct and data',
      'Use customer data only to fulfil bookings and provide customer support. Do not misuse QR receipts, create false bookings, send unsolicited marketing, discriminate unlawfully, or use KeshKart for unlawful, unsafe, fraudulent, or abusive activity. Protect access to your account and do not share OTPs or credentials.',
    ),
    _LegalSection(
      '5. Approval and enforcement',
      'KeshKart may review your profile, shop evidence, services, and platform activity. We may limit visibility, pause bookings, suspend, or remove an account where information is inaccurate, customer safety is at risk, these terms are breached, or action is reasonably required to protect users or the platform.',
    ),
    _LegalSection(
      '6. Changes to these terms',
      'We may update these terms to reflect service, operational, or legal changes. The updated version will be posted on KeshKart with its effective date. Continued use after that date means you accept the updated terms to the extent permitted by law.',
    ),
  ];
}

class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

  static const _ink = Color(0xFF091426);
  static const _muted = Color(0xFF54647A);
  static const _coral = Color(0xFFE2613B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _ink,
        elevation: 0,
        title: const Text(
          'Delete KeshKart account',
          style: TextStyle(fontWeight: FontWeight.w900),
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account and data deletion',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You must sign in to protect your account from unauthorised deletion.',
                        style: TextStyle(
                          color: Color(0xFFD6DFEC),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _LegalSectionCard(
                  section: _LegalSection(
                    'How to delete your account',
                    '1. Sign in to KeshKart using the mobile number linked to the account.\n\n2. In the KeshKart Customer app or website, open Profile.\n\n3. Choose Delete account and then choose Delete Forever to confirm.\n\nYour account is closed immediately and active sign-in sessions are revoked. You cannot undo this action.',
                  ),
                ),
                const SizedBox(height: 16),
                const _LegalSectionCard(
                  section: _LegalSection(
                    'What happens to your data',
                    'We delete or deactivate account data as part of the request, including account access, profile information, and customer booking preferences. We may retain the minimum information needed for legal obligations, fraud prevention, dispute handling, security, and completed booking records. Retained information is not used to reactivate your account.',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _coral.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Need help accessing your account? Do not share an OTP or password. Use the registered mobile number to sign in, then complete the deletion request from Profile.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
