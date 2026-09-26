import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/calendar_file.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingReceiptPage extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const BookingReceiptPage({super.key, required this.appointment});

  @override
  State<BookingReceiptPage> createState() => _BookingReceiptPageState();
}

class _BookingReceiptPageState extends State<BookingReceiptPage> {
  static const _ink = Color(0xFF091426);
  static const _green = Color(0xFF00A86B);

  String? _qrPayload;
  bool _loadingReceipt = true;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    final appointmentId = _text(
      widget.appointment['id'],
      fallback: _text(widget.appointment['_id']),
    );
    if (appointmentId.isEmpty) {
      if (mounted) setState(() => _loadingReceipt = false);
      return;
    }

    final receipt = await BedrockClient().issueAppointmentReceipt(
      appointmentId,
    );
    if (!mounted) return;
    setState(() {
      _qrPayload = receipt?['qrPayload']?.toString();
      _loadingReceipt = false;
    });
  }

  DateTime get _start {
    final value = widget.appointment['slotStart'] ?? widget.appointment['time'];
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  DateTime get _end {
    final value = widget.appointment['slotEnd'];
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.tryParse(value?.toString() ?? '') ??
        _start.add(const Duration(minutes: 30));
  }

  String get _shopName =>
      _text(widget.appointment['shopName'], fallback: 'KeshKart booking');

  String get _bookingReference => _text(
    widget.appointment['id'],
    fallback: _text(widget.appointment['_id'], fallback: 'Pending'),
  );

  String get _location => _text(widget.appointment['shopAddress']);

  Future<void> _openGoogleCalendar() async {
    final url = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'KeshKart - $_shopName',
      'dates': '${_googleDate(_start)}/${_googleDate(_end)}',
      'details': 'Booking reference: $_bookingReference',
      if (_location.isNotEmpty) 'location': _location,
    });
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Could not open Google Calendar.');
    }
  }

  void _downloadCalendar() {
    final downloaded = downloadCalendarFile(
      _calendarFile(),
      'keshkart-${_bookingReference.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')}.ics',
    );
    if (!downloaded) {
      _showMessage('Calendar downloads are available on keshkart.com.');
    }
  }

  String _calendarFile() {
    final description = 'Booking reference: $_bookingReference';
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//KeshKart//Booking//EN',
      'BEGIN:VEVENT',
      'UID:$_bookingReference@keshkart.com',
      'DTSTAMP:${_icsDate(DateTime.now())}',
      'DTSTART:${_icsDate(_start)}',
      'DTEND:${_icsDate(_end)}',
      'SUMMARY:${_icsEscape('KeshKart - $_shopName')}',
      'DESCRIPTION:${_icsEscape(description)}',
      if (_location.isNotEmpty) 'LOCATION:${_icsEscape(_location)}',
      'BEGIN:VALARM',
      'TRIGGER:-PT2H',
      'ACTION:DISPLAY',
      'DESCRIPTION:KeshKart appointment in 2 hours',
      'END:VALARM',
      'BEGIN:VALARM',
      'TRIGGER:-P1D',
      'ACTION:DISPLAY',
      'DESCRIPTION:KeshKart appointment tomorrow',
      'END:VALARM',
      'END:VEVENT',
      'END:VCALENDAR',
      '',
    ].join('\r\n');
  }

  String _googleDate(DateTime value) =>
      "${DateFormat("yyyyMMdd'T'HHmmss").format(value.toUtc())}Z";

  String _icsDate(DateTime value) => _googleDate(value);

  String _icsEscape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('EEEE, d MMM • h:mm a').format(_start);
    final service = _text(
      widget.appointment['service'],
      fallback: 'Appointment',
    );
    final reminder = _text(
      widget.appointment['reminderChannel'],
      fallback: 'calendar',
    );
    final seat = _text(widget.appointment['seatName']);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Booking receipt'),
        backgroundColor: const Color(0xFFF7F8FA),
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE1E3E4)),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFFE7F8F0),
                        child: Icon(
                          Icons.check_rounded,
                          color: _green,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Your booking is confirmed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        time,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF54647A)),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child:
                            _loadingReceipt
                                ? const SizedBox(
                                  height: 176,
                                  width: 176,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                : _qrPayload == null || _qrPayload!.isEmpty
                                ? const SizedBox(
                                  height: 176,
                                  child: Center(
                                    child: Text(
                                      'Receipt unavailable. Refresh from your bookings to try again.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                                : QrImageView(
                                  data: _qrPayload!,
                                  size: 176,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: _ink,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: _ink,
                                  ),
                                ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Show this QR to your barber when you arrive.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF54647A),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _detailCard(
                  title: _shopName,
                  subtitle: '$service${seat.isEmpty ? '' : ' · $seat'}\n$time',
                  icon: Icons.content_cut_rounded,
                ),
                const SizedBox(height: 12),
                _detailCard(
                  title: 'Booking reference',
                  subtitle: _bookingReference,
                  icon: Icons.confirmation_number_outlined,
                ),
                const SizedBox(height: 12),
                _detailCard(
                  title: 'Pay at the shop',
                  subtitle:
                      'Pay your barber directly when you visit. KeshKart does not collect payment for this appointment.',
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reminder',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reminder == 'calendar'
                      ? 'Add this appointment to your calendar for reminders.'
                      : 'Your selected reminder channel is ${_label(reminder)}.',
                  style: const TextStyle(color: Color(0xFF54647A), height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openGoogleCalendar,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: const Text('Google Calendar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _downloadCalendar,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Apple / Outlook'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E3E4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF54647A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(String value) {
    if (value == 'whatsapp') return 'WhatsApp';
    if (value == 'sms') return 'SMS';
    if (value == 'email') return 'email';
    if (value == 'none') return 'no direct reminder';
    return value;
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
