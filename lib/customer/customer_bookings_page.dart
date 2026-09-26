import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bedrock_client.dart';
import '../theme/keshkart_theme.dart';
import 'booking_receipt_page.dart';
import 'discovery_view.dart' show appointmentMillis;

class CustomerBookingsPage extends StatefulWidget {
  const CustomerBookingsPage({super.key, this.loader});
  final Future<List<dynamic>> Function()? loader;
  @override
  State<CustomerBookingsPage> createState() => _CustomerBookingsPageState();
}

class _CustomerBookingsPageState extends State<CustomerBookingsPage> {
  bool _loading = true, _history = false;
  String? _error;
  List<Map<String, dynamic>> _appointments = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final user =
          prefs.getString('bedrock_user_id') ?? prefs.getString('userId');
      if (widget.loader == null && (user == null || user.isEmpty)) {
        throw StateError('Sign in to see your appointments.');
      }
      final rows =
          await (widget.loader?.call() ??
              BedrockClient().queryCollection(
                'appointments',
                params: {'customerId': user!},
                throwOnError: true,
              ));
      final parsed =
          rows
              .whereType<Map>()
              .map(
                (r) => <String, dynamic>{
                  ...Map<String, dynamic>.from(
                    r['data'] is Map ? r['data'] : r,
                  ),
                  if (r['id'] != null) 'id': r['id'],
                },
              )
              .toList();
      if (mounted) {
        setState(() {
          _appointments = parsed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'We could not load your appointments. Please retry.';
        });
      }
    }
  }

  bool _isUpcoming(Map<String, dynamic> row) =>
      [
        'booked',
        'scheduled',
        'confirmed',
        'arrived',
        'in_progress',
      ].contains(row['status']) &&
      _activeUntilMillis(row) >= DateTime.now().millisecondsSinceEpoch;

  int _activeUntilMillis(Map<String, dynamic> row) {
    final slotEnd = appointmentMillis(row['slotEnd']);
    if (slotEnd > 0) return slotEnd;

    final slotStart = appointmentMillis(row['slotStart']);
    final duration = int.tryParse('${row['totalDurationMinutes'] ?? 30}') ?? 30;
    return slotStart + duration.clamp(5, 360) * 60 * 1000;
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        _appointments.where((r) => _history != _isUpcoming(r)).toList()..sort(
          (a, b) =>
              _history
                  ? appointmentMillis(
                    b['slotStart'],
                  ).compareTo(appointmentMillis(a['slotStart']))
                  : appointmentMillis(
                    a['slotStart'],
                  ).compareTo(appointmentMillis(b['slotStart'])),
        );
    return Scaffold(
      backgroundColor: KeshColors.warmIvory,
      appBar: AppBar(
        title: const Text('Your appointments'),
        actions: [
          IconButton(
            tooltip: 'Refresh appointments',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'A little time,\njust for you.',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Keep track of your next visit. Revisit your favourites.',
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.event_outlined),
                        label: Text('Upcoming & active'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.history),
                        label: Text('History'),
                      ),
                    ],
                    selected: {_history},
                    onSelectionChanged:
                        (s) => setState(() => _history = s.first),
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  else ...[
                    if (_appointments.length >= 100)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('Showing up to 100 loaded appointments.'),
                      ),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 50),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.event_available_outlined,
                              size: 48,
                              color: KeshColors.signatureCoral,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _history
                                  ? 'Your visit history starts here'
                                  : 'Your next visit is waiting',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Find your barber on Discover and choose a time.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    for (final r in rows) _card(r),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final time = appointmentMillis(row['slotStart']);
    final date = time > 0 ? DateTime.fromMillisecondsSinceEpoch(time) : null;
    final status = '${row['status'] ?? 'Unknown'}'.replaceAll('_', ' ');
    final reason = '${row['cancelReason'] ?? row['rescheduleReason'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KeshColors.borderIvory),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(label: Text(status)),
              Chip(
                label: Text(
                  date == null
                      ? 'Date unavailable'
                      : DateFormat('EEE, d MMM').format(date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${row['shopName'] ?? row['barberName'] ?? 'Barber shop'}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            date == null
                ? 'Check your receipt for details'
                : DateFormat('h:mm a · d MMMM y').format(date),
            style: const TextStyle(color: KeshColors.textSecondary),
          ),
          if (reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(reason),
            ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingReceiptPage(appointment: row),
                ),
              );
              if (mounted) _load();
            },
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Appointment details & receipt'),
          ),
        ],
      ),
    );
  }
}
