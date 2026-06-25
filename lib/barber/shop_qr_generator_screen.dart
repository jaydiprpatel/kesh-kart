import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../bedrock_client.dart';

class ShopQrGeneratorScreen extends StatefulWidget {
  final String shopId;

  const ShopQrGeneratorScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ShopQrGeneratorScreen> createState() => _ShopQrGeneratorScreenState();
}

class _ShopQrGeneratorScreenState extends State<ShopQrGeneratorScreen> with WidgetsBindingObserver {
  Timer? _sessionTimer;
  bool _isGenerating = false;
  String _currentSessionId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generateNewSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _generateNewSession();
    }
  }

  String _generateRandomString(int len) {
    final r = Random();
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _generateNewSession() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final sessionId = _generateRandomString(16);
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 45));

      // Note: If using a custom ID with createDocument, you might need an updateDocument or UPSERT logic.
      // Bedrock custom endpoint might handle this differently. 
      // Using updateDocument to UPSERT the shop's session.
      await BedrockClient().updateDocument('shop_sessions', widget.shopId, {
        'shopId': widget.shopId,
        'sessionId': sessionId,
        'startedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      });

      setState(() {
        _currentSessionId = sessionId;
      });

      // Restart the 30-minute auto-refresh timer
      _sessionTimer?.cancel();
      _sessionTimer = Timer(const Duration(minutes: 30), () {
        _generateNewSession();
      });
    } catch (e) {
      debugPrint("Error generating session: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate session: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isGenerating ? null : _generateNewSession,
            tooltip: 'Force Refresh Session',
          )
        ],
      ),
      body: Center(
        child: _isGenerating
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Scan to Check In',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // In a real app, use qr_flutter to render the QR. 
                  // For now, simulating the QR container.
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2, size: 150, color: Colors.grey.shade800),
                          const SizedBox(height: 10),
                          Text('Shop ID: ${widget.shopId}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'This QR code auto-refreshes for security.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Session: $_currentSessionId',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }
}
