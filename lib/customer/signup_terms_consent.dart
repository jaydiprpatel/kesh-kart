import 'package:flutter/material.dart';

import 'legal_document_page.dart';

class SignupTermsConsent extends StatelessWidget {
  final LegalAudience audience;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const SignupTermsConsent({
    super.key,
    required this.audience,
    required this.accepted,
    required this.onChanged,
  });

  String get _summary =>
      audience == LegalAudience.barber
          ? 'I will keep my shop, services, prices, duration, availability and customer handling accurate, and I accept the barber platform rules.'
          : 'I understand that the barber provides the service and is paid directly at the shop. Repeated cancellations, rescheduling, no-shows, or misuse may restrict my account.';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accepted ? const Color(0xFFE2613B) : const Color(0xFFE1E3E4),
        ),
      ),
      child: CheckboxListTile(
        value: accepted,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'I agree to the Terms & Conditions and Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(_summary, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 4),
            Wrap(
              children: [
                TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => LegalDocumentPage(
                                document: LegalDocument.terms,
                                audience: audience,
                              ),
                        ),
                      ),
                  child: const Text('Read terms'),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => const LegalDocumentPage(
                                document: LegalDocument.privacy,
                              ),
                        ),
                      ),
                  child: const Text('Privacy policy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
