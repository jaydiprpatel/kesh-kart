import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/qr_scanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerBookingsPage extends StatefulWidget {
  const CustomerBookingsPage({super.key});

  @override
  State<CustomerBookingsPage> createState() => _CustomerBookingsPageState();
}

class _CustomerBookingsPageState extends State<CustomerBookingsPage> {
  static const Color _primary = Color(0xFF091426);
  static const Color _green = Color(0xFF00D084);

  bool _loading = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId =
        prefs.getString('bedrock_user_id') ?? prefs.getString('userId');
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _appointments = [];
        _loading = false;
      });
      return;
    }

    final rows = await BedrockClient().queryCollection(
      'appointments',
      params: {'customerId': userId},
    );
    final appointments =
        rows.map(_normalize).where((row) => row.isNotEmpty).toList();
    appointments.sort((a, b) {
      final aStart = _millis(a['slotStart']);
      final bStart = _millis(b['slotStart']);
      return bStart.compareTo(aStart);
    });

    if (!mounted) return;
    setState(() {
      _appointments = appointments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Bookings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            },
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : RefreshIndicator(
                onRefresh: _loadBookings,
                color: _primary,
                backgroundColor: Colors.white,
                child:
                    _appointments.isEmpty
                        ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 160),
                            Icon(
                              Icons.calendar_month,
                              color: Color(0xFFC5C6CD),
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No bookings yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Book a barber from Home and your appointments will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF45474C)),
                            ),
                          ],
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _appointments.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _appointments[index];
                            final date = DateTime.fromMillisecondsSinceEpoch(
                              _millis(item['slotStart']),
                            );
                            final reason = _text(
                              item['cancelReason'] ?? item['rescheduleReason'],
                            );
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE1E3E4),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: _primary,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _text(
                                            item['shopName'],
                                            fallback: 'KeshKart booking',
                                          ),
                                          style: const TextStyle(
                                            color: _primary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          DateFormat(
                                            'EEE, d MMM • h:mm a',
                                          ).format(date),
                                          style: const TextStyle(
                                            color: Color(0xFF8590A6),
                                          ),
                                        ),
                                        if (reason.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            reason,
                                            style: const TextStyle(
                                              color: Color(0xFF54647A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _text(
                                      item['status'],
                                      fallback: 'booked',
                                    ).toUpperCase(),
                                    style: const TextStyle(
                                      color: _green,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
    );
  }

  static Map<String, dynamic> _normalize(dynamic row) {
    if (row is! Map) return {};
    final data = row['data'];
    if (data is Map) {
      return {...Map<String, dynamic>.from(data), 'id': row['id']};
    }
    return Map<String, dynamic>.from(row);
  }

  static int _millis(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return DateTime.tryParse(value?.toString() ?? '')?.millisecondsSinceEpoch ??
        0;
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
