import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectSlotScreen extends StatefulWidget {
  final Map<String, dynamic> barber;

  const SelectSlotScreen({super.key, required this.barber});

  @override
  State<SelectSlotScreen> createState() => _SelectSlotScreenState();
}

class _SelectSlotScreenState extends State<SelectSlotScreen> {
  static const Color _primary = Color(0xFF091426);

  final List<String> _slots = const [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
  ];

  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final shopName = _text(
      widget.barber['shopName'],
      fallback: _text(widget.barber['name'], fallback: 'Barber Shop'),
    );
    final photo = _firstPhoto(widget.barber);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Select slot',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E3E4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child:
                      photo == null
                          ? Image.asset(
                            'assets/images/barber.png',
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          )
                          : Image.network(
                            photo,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Image.asset(
                                  'assets/images/barber.png',
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                          ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _text(
                          widget.barber['shopAddress'],
                          fallback: 'Choose your preferred time',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF8590A6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Choose date',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final selected = _sameDay(date, _selectedDate);
                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: _primary,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? _primary : const Color(0xFFE1E3E4),
                  ),
                  label: SizedBox(
                    width: 68,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            color:
                                selected
                                    ? Colors.white
                                    : const Color(0xFF8590A6),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d MMM').format(date),
                          style: TextStyle(
                            color: selected ? Colors.white : _primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onSelected: (_) => setState(() => _selectedDate = date),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Available slots',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _slots.map((slot) {
                  final selected = _selectedSlot == slot;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(slot),
                    selectedColor: _primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? _primary : const Color(0xFFE1E3E4),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _primary,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) => setState(() => _selectedSlot = slot),
                  );
                }).toList(),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed:
                  _selectedSlot == null || _isBooking ? null : _createBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE1E3E4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  _isBooking
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        'Confirm booking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBooking() async {
    final slot = _selectedSlot;
    if (slot == null) return;

    setState(() => _isBooking = true);
    final prefs = await SharedPreferences.getInstance();
    final userId =
        prefs.getString('bedrock_user_id') ?? prefs.getString('userId');
    final customerName = prefs.getString('name') ?? 'Customer';

    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() => _isBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to book a slot.')),
      );
      return;
    }

    final start = _slotDateTime(_selectedDate, slot);
    final end = start.add(const Duration(minutes: 30));
    final shopId = _text(
      widget.barber['id'],
      fallback: _text(
        widget.barber['_id'],
        fallback: _text(widget.barber['uid']),
      ),
    );

    final response = await BedrockClient().createDocument('appointments', {
      'customerId': userId,
      'customerName': customerName,
      'shopId': shopId,
      'shopName': _text(
        widget.barber['shopName'],
        fallback: _text(widget.barber['name'], fallback: 'Barber Shop'),
      ),
      'barberId': shopId,
      'slotStart': start.millisecondsSinceEpoch,
      'slotEnd': end.millisecondsSinceEpoch,
      'status': 'booked',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    if (!mounted) return;
    setState(() => _isBooking = false);
    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create booking. Try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Booking confirmed.')));
    Navigator.pop(context, true);
  }

  DateTime _slotDateTime(DateTime date, String slot) {
    final parsed = DateFormat('hh:mm a').parse(slot);
    return DateTime(
      date.year,
      date.month,
      date.day,
      parsed.hour,
      parsed.minute,
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _firstPhoto(Map<String, dynamic> barber) {
    final photos = barber['shopPhotos'];
    if (photos is List && photos.isNotEmpty && photos.first is String) {
      final photo = photos.first.toString();
      return photo.isEmpty ? null : photo;
    }
    return null;
  }
}
