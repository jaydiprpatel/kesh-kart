import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/payment_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final payment = context.read<PaymentProvider>();
      await payment.refreshCurrentSubscription();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      await context.read<PaymentProvider>().pollStatus();
      final status = context.read<PaymentProvider>().status;
      if (status == 'active') {
        timer.cancel();
        _showSuccessDialog();
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Success!"),
        content: const Text(
          "Your subscription is now active. You are visible to customers.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text("Awesome"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User session error. Please log in again.")),
      );
      return;
    }

    final payment = context.read<PaymentProvider>();
    final alreadyActive = await payment.refreshCurrentSubscription();
    if (alreadyActive) {
      _showSuccessDialog();
      return;
    }

    await payment.createSubscription(userId);

    if (payment.approvalUrl != null) {
      final url = Uri.parse(payment.approvalUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        _startPolling();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch payment gateway.")),
        );
      }
    } else if (payment.error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(payment.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = context.watch<PaymentProvider>();
    final isActive = payment.status == 'active';
    final isPending = payment.status == 'pending';
    final isTimeout = payment.status == 'timeout';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pro Subscription"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.stars_rounded,
              size: 80,
              color: Color(0xFF00D189),
            ),
            const SizedBox(height: 24),
            Text(
              "Upgrade to KeshKart Pro",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Stay active on the platform and reach more customers near you.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            _buildPriceCard(),
            const SizedBox(height: 32),
            _buildBenefitRow(
              Icons.check_circle_outline,
              "Visible on customer radar",
            ),
            _buildBenefitRow(
              Icons.check_circle_outline,
              "Accept online bookings",
            ),
            _buildBenefitRow(
              Icons.check_circle_outline,
              "Analytics and insights",
            ),
            const Spacer(),
            if (isActive)
              _buildActiveState()
            else if (isPending)
              _buildConfirmationState()
            else if (isTimeout)
              _buildTimeoutState()
            else
              _buildSubscribeButton(payment),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutState() {
    return Column(
      children: [
        const Icon(Icons.timer_off_outlined, color: Colors.grey, size: 40),
        const SizedBox(height: 16),
        Text(
          "Confirmation taking longer than expected.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          "If you have already paid, don't worry! Your status will update automatically once the bank confirms.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.blueGrey),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.read<PaymentProvider>().pollStatus(),
          child: const Text("Check Status Manually"),
        ),
        TextButton(
          onPressed: () => context.read<PaymentProvider>().reset(),
          child: const Text("Try Again", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2C33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D189).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            "Monthly Plan",
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "\u20B9",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00D189),
                ),
              ),
              Text(
                "350",
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  "/month",
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00D189)),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.poppins(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildConfirmationState() {
    return Column(
      children: [
        const CircularProgressIndicator(color: Color(0xFF00D189)),
        const SizedBox(height: 16),
        Text(
          "Waiting for confirmation...",
          style: GoogleFonts.poppins(color: Colors.orangeAccent),
        ),
        TextButton(
          onPressed: () => context.read<PaymentProvider>().reset(),
          child: const Text("Try Again", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildActiveState() {
    return Column(
      children: [
        const Icon(Icons.verified_rounded, color: Color(0xFF00D189), size: 40),
        const SizedBox(height: 16),
        Text(
          "Your Pro access is active.",
          style: GoogleFonts.poppins(color: const Color(0xFF00D189)),
        ),
        const SizedBox(height: 8),
        Text(
          "Your shop can be shown to customers whenever verification and live status allow it.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.blueGrey),
        ),
      ],
    );
  }

  Widget _buildSubscribeButton(PaymentProvider payment) {
    return ElevatedButton(
      onPressed: payment.isLoading ? null : _handleSubscribe,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00D189),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: payment.isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              "SUBSCRIBE NOW",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
    );
  }
}
