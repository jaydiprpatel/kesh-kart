import 'package:flutter/material.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarberReceiptScannerScreen extends StatefulWidget {
  const BarberReceiptScannerScreen({super.key});

  @override
  State<BarberReceiptScannerScreen> createState() =>
      _BarberReceiptScannerScreenState();
}

class _BarberReceiptScannerScreenState
    extends State<BarberReceiptScannerScreen> {
  final MobileScannerController _camera = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final payload = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (payload.isEmpty) return;

    setState(() => _processing = true);
    await _camera.stop();
    final result = await BedrockClient().checkInWithReceipt(payload);
    if (!mounted) return;

    final success = result?['success'] == true;
    final alreadyCheckedIn = result?['alreadyCheckedIn'] == true;
    if (success) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              icon: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF00A86B),
              ),
              title: Text(
                alreadyCheckedIn ? 'Already checked in' : 'Customer checked in',
              ),
              content: Text(
                alreadyCheckedIn
                    ? 'This booking is already in your queue.'
                    : 'The customer has been marked as arrived.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
      );
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This receipt could not be verified for your shop.'),
      ),
    );
    setState(() => _processing = false);
    await _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan customer receipt'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _camera, onDetect: _onDetect),
          Center(
            child: Container(
              width: 252,
              height: 252,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Scan the QR shown on the customer\'s KeshKart receipt to check them in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_processing)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
