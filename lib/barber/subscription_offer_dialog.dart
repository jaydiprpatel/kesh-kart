import 'package:flutter/material.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/theme/keshkart_theme.dart';

/// Reviews a server-signed subscription quote before a payment order is made.
///
/// A coupon is optional. Opening this dialog always requests the normal plan
/// price first, so the barber can continue to secure payment without a code.
class SubscriptionOfferDialog extends StatefulWidget {
  const SubscriptionOfferDialog({
    super.key,
    required this.plan,
    this.planName = 'KeshKart Pro',
    this.regularAmountPaise,
    this.quoteLoader,
  });

  final String plan;
  final String planName;
  final int? regularAmountPaise;
  final Future<Map<String, dynamic>?> Function(String plan, String coupon)?
  quoteLoader;

  @override
  State<SubscriptionOfferDialog> createState() =>
      _SubscriptionOfferDialogState();
}

class _SubscriptionOfferDialogState extends State<SubscriptionOfferDialog> {
  final _coupon = TextEditingController();
  Map<String, dynamic>? _quote;
  bool _busy = false;
  bool _accepted = false;
  String? _error;

  bool get _hasCoupon => _coupon.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _quote = null;
      _accepted = false;
    });
    final loader =
        widget.quoteLoader ?? BedrockClient.instance.quoteKeshKartSubscription;
    final data = await loader(widget.plan, _coupon.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data == null || data['error'] != null) {
        _error =
            data?['error']?.toString() ??
            'We could not prepare a secure price right now.';
      } else {
        _quote = data;
      }
    });
  }

  String _money(dynamic paise) =>
      '₹${((paise as num? ?? 0) / 100).toStringAsFixed(0)}';

  String get _displayAmount {
    final quote = _quote;
    if (quote != null) return _money(quote['amount']);
    if (widget.regularAmountPaise != null) {
      return _money(widget.regularAmountPaise);
    }
    return '—';
  }

  void _showTerms(Map<String, dynamic> quote) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Subscription terms'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: SelectableText(quote['terms'].toString()),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final canContinue = !_busy && _accepted && quote != null;
    final isFree = quote?['amount'] == 0;
    final actionLabel =
        isFree ? 'Activate free access' : 'Pay $_displayAmount securely';

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: KeshColors.warmIvory,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
                  decoration: const BoxDecoration(
                    color: KeshColors.navyPrimary,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: KeshColors.proGold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review subscription',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Secure one-time payment via Razorpay',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _planSummary(quote),
                        const SizedBox(height: 16),
                        _couponSection(),
                        if (_busy) ...[
                          const SizedBox(height: 14),
                          const LinearProgressIndicator(
                            color: KeshColors.signatureCoral,
                            backgroundColor: Color(0xFFE8EDF3),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _errorNotice(),
                        ],
                        if (quote != null) ...[
                          const SizedBox(height: 16),
                          _termsSection(quote),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE1E6EE))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            canContinue
                                ? () => Navigator.pop(context, quote)
                                : null,
                        icon: Icon(
                          isFree
                              ? Icons.verified_rounded
                              : Icons.lock_outline_rounded,
                        ),
                        label: Text(actionLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: KeshColors.navyPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE2E6EC),
                          disabledForegroundColor: const Color(0xFF8591A3),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your access changes only after verified payment confirmation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF66758A),
                          fontSize: 11,
                        ),
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
  }

  Widget _planSummary(Map<String, dynamic>? quote) {
    final originalAmount =
        quote?['original_amount'] ?? widget.regularAmountPaise;
    final discount = (quote?['discount'] as num?)?.toInt() ?? 0;
    final duration = quote?['duration_days'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E6EE)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.planName,
                  style: const TextStyle(
                    color: KeshColors.navyPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _displayAmount,
                style: const TextStyle(
                  color: KeshColors.navyPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            quote == null
                ? 'Preparing your secure price…'
                : '${duration ?? 30} days of KeshKart Pro access',
            style: const TextStyle(color: Color(0xFF54647A), fontSize: 13),
          ),
          if (quote != null && discount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'You save ${_money(discount)}${_hasCoupon ? ' with your code' : ''}',
                style: const TextStyle(
                  color: Color(0xFF087A42),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          if (quote != null && originalAmount != null && discount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Regular price ${_money(originalAmount)}',
              style: const TextStyle(
                color: Color(0xFF748196),
                fontSize: 12,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _couponSection() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9F5),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0DDD2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.local_offer_outlined,
              color: KeshColors.signatureCoral,
              size: 19,
            ),
            SizedBox(width: 8),
            Text(
              'Have a coupon?',
              style: TextStyle(
                color: KeshColors.navyPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Optional',
              style: TextStyle(color: Color(0xFF66758A), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _coupon,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter offer code',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE1E6EE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE1E6EE)),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _quote = null;
                    _accepted = false;
                    _error = null;
                  });
                  if (value.trim().isEmpty) _refresh();
                },
                onSubmitted: (_) => _refresh(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busy ? null : _refresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: KeshColors.signatureCoral,
                side: const BorderSide(color: KeshColors.signatureCoral),
                minimumSize: const Size(76, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_hasCoupon ? 'Apply' : 'Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'No code is needed. The regular price is already selected.',
          style: TextStyle(color: Color(0xFF66758A), fontSize: 12),
        ),
      ],
    ),
  );

  Widget _errorNotice() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0ED),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF3C7BC)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFFC43E23)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(color: Color(0xFF9E2D17), fontSize: 12),
          ),
        ),
        TextButton(onPressed: _refresh, child: const Text('Retry')),
      ],
    ),
  );

  Widget _termsSection(Map<String, dynamic> quote) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE1E6EE)),
    ),
    child: Column(
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          activeColor: KeshColors.navyPrimary,
          onChanged: (value) => setState(() => _accepted = value ?? false),
          title: const Text(
            'I agree to the subscription terms and conditions.',
            style: TextStyle(
              color: KeshColors.navyPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showTerms(quote),
            icon: const Icon(Icons.description_outlined, size: 17),
            label: const Text('Read full terms'),
            style: TextButton.styleFrom(
              foregroundColor: KeshColors.signatureCoral,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );
}
