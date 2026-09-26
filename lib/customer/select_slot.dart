import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/booking_receipt_page.dart';
import 'package:kesh_kart/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectSlotScreen extends StatefulWidget {
  final Map<String, dynamic> barber;
  final List<Map<String, dynamic>> selectedServices;

  const SelectSlotScreen({
    super.key,
    required this.barber,
    required this.selectedServices,
  });

  @override
  State<SelectSlotScreen> createState() => _SelectSlotScreenState();
}

class _SelectSlotScreenState extends State<SelectSlotScreen> {
  static const Color _primary = Color(0xFF091426);

  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;
  List<Map<String, dynamic>> _seats = const [];
  String? _selectedSeatId;
  bool _seatsLoading = true;
  String? _seatsError;
  String _reminderChannel = 'calendar';
  bool _isBooking = false;

  String get _shopId => _text(
    widget.barber['id'],
    fallback: _text(
      widget.barber['_id'],
      fallback: _text(widget.barber['uid']),
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    final shopId = _shopId;
    if (shopId.isEmpty) {
      setState(() {
        _seatsLoading = false;
        _seatsError = 'This shop is unavailable.';
      });
      return;
    }
    final response = await BedrockClient.instance.keshKartBookableSeats(shopId);
    if (!mounted) return;
    final rawSeats = response?['seats'];
    final seats =
        rawSeats is List
            ? rawSeats
                .whereType<Map>()
                .map((seat) => Map<String, dynamic>.from(seat))
                .where(
                  (seat) =>
                      _text(seat['id']).isNotEmpty &&
                      _text(seat['name']).isNotEmpty,
                )
                .toList()
            : <Map<String, dynamic>>[];
    setState(() {
      _seats = seats;
      _seatsLoading = false;
      _seatsError = response?['error']?.toString();
      if (seats.length == 1) _selectedSeatId = _text(seats.first['id']);
    });
  }

  bool get _shopIsOpen =>
      widget.barber.containsKey('isOpen')
          ? widget.barber['isOpen'] == true
          : widget.barber['isActive'] == true;

  int get _totalDurationMinutes => widget.selectedServices.fold(
    0,
    (total, service) => total + _serviceDuration(service),
  );

  double get _totalPrice => widget.selectedServices.fold(
    0,
    (total, service) => total + _servicePrice(service['price']),
  );

  List<String> _getAvailableSlots() {
    final opening = widget.barber['openingTime']?.toString() ?? '09:00 AM';
    final closing = widget.barber['closingTime']?.toString() ?? '08:00 PM';
    final rawInterval = widget.barber['slotIntervalMinutes'];
    final slotInterval =
        rawInterval is num
            ? rawInterval.toInt().clamp(5, 60).toInt()
            : int.tryParse('$rawInterval')?.clamp(5, 60).toInt() ?? 15;
    final durationMinutes = _totalDurationMinutes.clamp(5, 360).toInt();

    final openHour = _parseHour(opening, defaultHour: 9);
    final closeHour = _parseHour(closing, defaultHour: 20);

    final List<String> slots = [];
    final isToday = _sameDay(_selectedDate, DateTime.now());
    final now = DateTime.now();

    final closesAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      closeHour,
    );
    for (int hour = openHour; hour < closeHour; hour++) {
      for (int min = 0; min < 60; min += slotInterval) {
        final slotDt = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          hour,
          min,
        );
        if (isToday && slotDt.isBefore(now.add(const Duration(minutes: 10)))) {
          continue;
        }
        if (slotDt.add(Duration(minutes: durationMinutes)).isAfter(closesAt)) {
          continue;
        }
        slots.add(DateFormat('hh:mm a').format(slotDt));
      }
    }

    return slots;
  }

  int _parseHour(String timeStr, {required int defaultHour}) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final parts = clean
          .replaceAll('AM', '')
          .replaceAll('PM', '')
          .trim()
          .split(':');
      var hour = int.parse(parts[0]);
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return hour;
    } catch (_) {
      return defaultHour;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopName = _text(
      widget.barber['shopName'],
      fallback: _text(widget.barber['name'], fallback: 'Barber Shop'),
    );
    final photo = _firstPhoto(widget.barber);
    final availableSlots = _getAvailableSlots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Choose a time',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A091426),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed:
                  _selectedSeatId == null ||
                          _selectedSlot == null ||
                          _isBooking ||
                          !_shopIsOpen
                      ? null
                      : _createBooking,
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
                      : Text(
                        _shopIsOpen ? 'Confirm booking' : 'Shop is closed',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E3E4)),
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
                        '${widget.selectedServices.map((service) => _text(service['name'])).join(' · ')} · $_totalDurationMinutes min · ₹${_totalPrice.toStringAsFixed(_totalPrice.truncateToDouble() == _totalPrice ? 0 : 2)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF54647A),
                          fontWeight: FontWeight.w700,
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
            'Choose a seat',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your selected seat is reserved for the full service time.',
            style: TextStyle(color: Color(0xFF54647A), height: 1.35),
          ),
          const SizedBox(height: 12),
          if (_seatsLoading)
            const LinearProgressIndicator()
          else if (_seatsError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _seatsError!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
                TextButton(onPressed: _loadSeats, child: const Text('Retry')),
              ],
            )
          else if (_seats.isEmpty)
            const Text(
              'This shop has not added a bookable seat yet. Please contact the barber.',
              style: TextStyle(color: Color(0xFF54647A), height: 1.35),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  _seats.map((seat) {
                    final seatId = _text(seat['id']);
                    final selected = _selectedSeatId == seatId;
                    return ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.chair_outlined,
                        size: 18,
                        color: selected ? Colors.white : _primary,
                      ),
                      label: Text(_text(seat['name'])),
                      selectedColor: _primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? _primary : const Color(0xFFE1E3E4),
                      ),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : _primary,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected:
                          (_) => setState(() {
                            _selectedSeatId = seatId;
                            _selectedSlot = null;
                          }),
                    );
                  }).toList(),
            ),
          const SizedBox(height: 22),
          Text(
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
          Text(
            'Available slots · $_totalDurationMinutes min',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (availableSlots.isEmpty)
            const Text(
              'No time today fits this service length. Choose another date or ask the shop to update its hours.',
              style: TextStyle(color: Color(0xFF54647A), height: 1.35),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  availableSlots.map((slot) {
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
          const SizedBox(height: 22),
          const Text(
            'Reminder preference',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _reminderChannel,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE1E3E4)),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'push',
                child: Text('Browser push alerts'),
              ),
              DropdownMenuItem(
                value: 'calendar',
                child: Text('Calendar reminder'),
              ),
              DropdownMenuItem(value: 'email', child: Text('Email reminder')),
              DropdownMenuItem(
                value: 'whatsapp',
                child: Text('WhatsApp reminder'),
              ),
              DropdownMenuItem(value: 'sms', child: Text('SMS reminder')),
              DropdownMenuItem(
                value: 'none',
                child: Text('No direct reminder'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _reminderChannel = value);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Browser alerts keep you updated about this appointment, even when KeshKart is closed. Calendar reminders are available; WhatsApp and SMS are sent only after you opt in and KeshKart enables an approved provider.',
            style: TextStyle(
              color: Color(0xFF54647A),
              fontSize: 12,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC4AD)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.payments_outlined, color: Color(0xFFE85D39)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay at the shop',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Pay your barber directly when you visit. KeshKart does not collect payment for this appointment.',
                        style: TextStyle(
                          color: Color(0xFF54647A),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'By confirming, you agree to the ',
                style: TextStyle(color: Color(0xFF54647A), fontSize: 12),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/terms'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Terms', style: TextStyle(fontSize: 12)),
              ),
              const Text(
                ' and ',
                style: TextStyle(color: Color(0xFF54647A), fontSize: 12),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/privacy'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Text(
                '.',
                style: TextStyle(color: Color(0xFF54647A), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createBooking() async {
    final slot = _selectedSlot;
    final seatId = _selectedSeatId;
    if (slot == null || seatId == null) return;
    if (!_shopIsOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This shop is currently closed and cannot take bookings.',
          ),
        ),
      );
      return;
    }

    if (_reminderChannel == 'push') {
      final pushResult = await NotificationService.enablePushAlerts();
      if (!mounted) return;
      if (pushResult != PushAlertSetupResult.enabled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_pushAlertMessage(pushResult))));
        return;
      }
    }

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
    final end = start.add(Duration(minutes: _totalDurationMinutes));
    final shopId = _shopId;

    final liveShop = await BedrockClient().getDocument('users', shopId);
    final liveData =
        liveShop?['data'] is Map
            ? Map<String, dynamic>.from(liveShop!['data'])
            : liveShop ?? <String, dynamic>{};
    final liveOpen =
        liveData.containsKey('isOpen')
            ? liveData['isOpen'] == true
            : liveData['isActive'] == true;
    if (!liveOpen) {
      if (!mounted) return;
      setState(() => _isBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This shop just closed. Please choose another time later.',
          ),
        ),
      );
      return;
    }

    final response = await BedrockClient().createDocument('appointments', {
      'customerId': userId,
      'customerName': customerName,
      'shopId': shopId,
      'shopName': _text(
        widget.barber['shopName'],
        fallback: _text(widget.barber['name'], fallback: 'Barber Shop'),
      ),
      'barberId': shopId,
      'seatId': seatId,
      'services':
          widget.selectedServices
              .map((service) => {'name': _text(service['name'])})
              .toList(),
      'service': widget.selectedServices
          .map((service) => _text(service['name']))
          .join(' · '),
      'totalDurationMinutes': _totalDurationMinutes,
      'totalPrice': _totalPrice,
      'slotStart': start.millisecondsSinceEpoch,
      'slotEnd': end.millisecondsSinceEpoch,
      'shopAddress': _text(widget.barber['shopAddress']),
      'reminderChannel': _reminderChannel,
      'status': 'booked',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    }, preserveError: true);

    if (!mounted) return;
    setState(() => _isBooking = false);
    if (response == null || response['error'] != null) {
      final error = response?['error']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null || error.isEmpty
                ? 'Could not create booking. Try again.'
                : error,
          ),
        ),
      );
      return;
    }

    final bookingData = response['data'];
    final booking =
        bookingData is Map
            ? Map<String, dynamic>.from(bookingData)
            : <String, dynamic>{};
    booking['id'] = response['id']?.toString() ?? booking['id'];
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingReceiptPage(appointment: booking),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _pushAlertMessage(PushAlertSetupResult result) {
    switch (result) {
      case PushAlertSetupResult.vapidKeyMissing:
        return 'Browser alerts are not configured yet. Choose calendar reminders for now.';
      case PushAlertSetupResult.permissionDenied:
        return 'Browser alerts are blocked. Allow notifications in your browser settings, or choose calendar reminders.';
      case PushAlertSetupResult.tokenUnavailable:
      case PushAlertSetupResult.failed:
        return 'We could not enable browser alerts. Please retry or choose calendar reminders.';
      case PushAlertSetupResult.enabled:
        return '';
    }
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

  static int _serviceDuration(Map<String, dynamic> service) {
    final value = service['durationMinutes'] ?? service['duration'];
    final duration = value is num ? value.toInt() : int.tryParse('$value');
    return (duration == null || duration < 5)
        ? 30
        : duration.clamp(5, 360).toInt();
  }

  static double _servicePrice(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String? _firstPhoto(Map<String, dynamic> barber) {
    final photos = barber['shopPhotos'];
    final candidates = <dynamic>[
      if (photos is List) ...photos,
      barber['verifiedShopPhotoUrl'],
      barber['shopVerificationPhotoUrl'],
      barber['profileUrl'],
    ];
    for (final candidate in candidates) {
      final photo = candidate?.toString().trim() ?? '';
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        return photo;
      }
    }
    return null;
  }
}
