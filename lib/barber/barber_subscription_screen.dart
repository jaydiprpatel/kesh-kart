import 'package:flutter/material.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/layout/keshkart_desktop_frame.dart';
import 'package:kesh_kart/theme/keshkart_theme.dart';

import 'razorpay_checkout.dart';
import 'subscription_offer_dialog.dart';

class BarberSubscriptionScreen extends StatefulWidget {
  const BarberSubscriptionScreen({super.key});

  @override
  State<BarberSubscriptionScreen> createState() =>
      _BarberSubscriptionScreenState();
}

class _BarberSubscriptionScreenState extends State<BarberSubscriptionScreen> {
  bool _loading = true;
  bool _startingCheckout = false;
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plans = await BedrockClient.instance.getKeshKartSubscriptionPlans();
    final subscription = await BedrockClient.instance.getKeshKartSubscription();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _subscription = subscription;
      _loading = false;
    });
  }

  Future<void> _startCheckout(Map<String, dynamic> plan) async {
    if (_startingCheckout) return;
    final quote = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => SubscriptionOfferDialog(
            plan: plan['code'].toString(),
            planName: plan['name']?.toString() ?? 'KeshKart Pro',
            regularAmountPaise: (plan['amount_paise'] as num?)?.toInt(),
          ),
    );
    if (!mounted || quote == null) return;
    setState(() => _startingCheckout = true);
    try {
      final order = await BedrockClient.instance.createKeshKartRazorpayOrder(
        plan['code']?.toString() ?? '',
        quote: quote,
      );
      if (order == null) {
        throw Exception(
          'We could not start secure checkout. Please try again.',
        );
      }

      if (order['error'] != null) throw Exception(order['error']);
      if (order['free_access'] == true && order['status'] == 'active') {
        await _load();
        if (mounted) {
          _message('Your free access is active. No payment was taken.');
        }
        return;
      }

      final subscriptionId = order['subscription_id']?.toString() ?? '';
      final orderId = order['order_id']?.toString() ?? '';
      final keyId = order['key_id']?.toString() ?? '';
      final amount = (order['amount'] as num?)?.toInt() ?? 0;
      if (subscriptionId.isEmpty ||
          orderId.isEmpty ||
          keyId.isEmpty ||
          amount < 100) {
        throw Exception('The payment order is incomplete. Please try again.');
      }

      final response = await openKeshKartRazorpayCheckout({
        'key': keyId,
        'amount': amount,
        'currency': order['currency']?.toString() ?? 'INR',
        'name': order['name']?.toString() ?? 'KeshKart',
        'description':
            order['description']?.toString() ?? 'KeshKart Pro subscription',
        'order_id': orderId,
        'prefill':
            order['prefill'] is Map
                ? Map<String, dynamic>.from(order['prefill'] as Map)
                : const <String, dynamic>{},
        'notes': {'keshkart_subscription': subscriptionId},
        'theme': {'color': '#091426'},
      });

      final paymentId = response['razorpay_payment_id'] ?? '';
      final callbackOrderId = response['razorpay_order_id'] ?? '';
      final signature = response['razorpay_signature'] ?? '';
      if (paymentId.isEmpty || callbackOrderId.isEmpty || signature.isEmpty) {
        throw Exception(
          'Razorpay did not return a complete payment confirmation.',
        );
      }

      final verification = await BedrockClient.instance
          .verifyKeshKartRazorpayPayment(
            subscriptionId: subscriptionId,
            paymentId: paymentId,
            orderId: callbackOrderId,
            signature: signature,
          );
      await _load();
      if (!mounted) return;
      if (verification?['awaiting_webhook'] == true) {
        _message(
          'Payment received. KeshKart is confirming it securely; Pro will activate shortly.',
        );
      } else if (verification?['status']?.toString() == 'active') {
        _message(
          'Subscription is active. Your shop can now become discoverable.',
        );
      } else {
        _message(
          'Payment verification is still pending. Refresh this page in a moment.',
        );
      }
    } catch (error) {
      final detail = error.toString().replaceFirst('Exception: ', '');
      _message(
        detail == 'Payment window closed.'
            ? 'Checkout cancelled. No subscription was activated.'
            : detail,
      );
    } finally {
      if (mounted) setState(() => _startingCheckout = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final active = _subscription?['is_access_active'] == true;
    final pendingConfirmation =
        !active &&
        (_subscription?['status']?.toString() == 'pending' ||
            _subscription?['last_payment']?.toString() ==
                'captured_awaiting_webhook');
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('KeshKart Pro'),
        backgroundColor: Colors.white,
        foregroundColor: KeshColors.navyPrimary,
        elevation: 0,
      ),
      body: KeshKartDesktopFrame(
        maxWidth: 840,
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: KeshColors.navyPrimary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              active
                                  ? Icons.verified_rounded
                                  : pendingConfirmation
                                  ? Icons.hourglass_top_rounded
                                  : Icons.workspace_premium_rounded,
                              color: KeshColors.proGold,
                              size: 30,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              active
                                  ? 'Your Pro subscription is active'
                                  : pendingConfirmation
                                  ? 'Your payment is being confirmed'
                                  : 'Keep your shop bookable with Pro',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              active
                                  ? 'Your booking link and discovery eligibility stay protected.'
                                  : pendingConfirmation
                                  ? 'Razorpay payment was received. KeshKart will activate Pro after the signed confirmation arrives.'
                                  : 'Pay securely with Razorpay. Your access changes only after KeshKart receives the verified payment confirmation.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.74),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_subscription?['next_billing'] != null)
                        Text(
                          'Access ${active ? 'until' : 'ended'}: ${DateTime.tryParse(_subscription!['next_billing'].toString())?.toLocal().toString().split(' ').first ?? _subscription!['next_billing']}',
                        ),
                      if (pendingConfirmation)
                        _pendingConfirmationCard()
                      else ...[
                        Text(
                          active ? 'Your plan' : 'Choose your plan',
                          style: const TextStyle(
                            color: KeshColors.navyPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_plans.isEmpty)
                          const Text(
                            'Plans are temporarily unavailable. Please try again later.',
                          )
                        else
                          ..._plans.map((plan) => _planCard(plan, active)),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Razorpay Standard Checkout supports UPI, cards, netbanking, and wallets. This is a one-time payment for the displayed plan period, not an AutoPay mandate.',
                        style: TextStyle(
                          color: Color(0xFF54647A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _pendingConfirmationCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9E8),
      border: Border.all(color: const Color(0xFFF2D790)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: Color(0xFF9A6700)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Payment confirmation pending',
                style: TextStyle(
                  color: KeshColors.navyPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const Text(
          'Do not make another payment. Pull down to refresh, or tap below after a moment.',
          style: TextStyle(color: Color(0xFF66521A)),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Check payment status'),
          style: OutlinedButton.styleFrom(
            foregroundColor: KeshColors.navyPrimary,
            side: const BorderSide(color: KeshColors.navyPrimary),
          ),
        ),
      ],
    ),
  );

  Widget _planCard(Map<String, dynamic> plan, bool active) {
    final amountPaise = (plan['amount_paise'] as num?)?.toInt() ?? 0;
    final amount = (amountPaise / 100).toStringAsFixed(0);
    final interval = plan['interval']?.toString() ?? 'monthly';
    final benefits =
        (plan['benefits'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E3E4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan['name']?.toString() ?? 'KeshKart Pro',
                  style: const TextStyle(
                    color: KeshColors.navyPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '₹$amount/$interval',
                style: const TextStyle(
                  color: KeshColors.navyPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if ((plan['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              plan['description'].toString(),
              style: const TextStyle(color: Color(0xFF54647A)),
            ),
          ],
          ...benefits
              .take(3)
              .map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: KeshColors.emeraldSuccess,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  active || _startingCheckout
                      ? null
                      : () => _startCheckout(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: KeshColors.navyPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child:
                  _startingCheckout
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(active ? 'Active' : 'Review price / apply coupon'),
            ),
          ),
        ],
      ),
    );
  }
}
