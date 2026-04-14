import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectSlotScreen extends StatefulWidget {
  final String barberId;
  final String barberName;
  final String? rescheduleAppointmentId;
  final String? initialService;

  const SelectSlotScreen({
    super.key,
    required this.barberId,
    required this.barberName,
    this.rescheduleAppointmentId,
    this.initialService,
  });

  @override
  State<SelectSlotScreen> createState() => _SelectSlotScreenState();
}

class _SelectSlotScreenState extends State<SelectSlotScreen> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> selectedServices = [];
  DateTime? selectedSlot;
  Map<String, dynamic>? selectedStaff;
  bool isLoading = true;
  bool isBooking = false;

  String? _specialNotes;
  String? _referencePhotoUrl;

  final double _discountAmount = 0.0;

  Map<String, dynamic>? barberAvailability;
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> staffList = [];
  List<Map<String, dynamic>> bookedSlots = [];

  @override
  void initState() {
    super.initState();
    _loadBarberData();
    if (widget.rescheduleAppointmentId != null) {
      _loadAppointmentData();
    }
  }

  Future<void> _loadAppointmentData() async {
    try {
      final doc =
          await BaasClient.collection(
            'appointments',
          ).doc(widget.rescheduleAppointmentId!).get();
      if (doc.exists) {
        final data = doc.data()!;
        final rawTime = data['time'];
        final time =
            rawTime is Timestamp
                ? rawTime.toDate()
                : DateTime.tryParse(rawTime.toString()) ?? DateTime.now();

        setState(() {
          selectedDate = time;
          _specialNotes = data['specialNotes'];
          // We'll try to match services after barber data loads
        });
      }
    } catch (e) {
      debugPrint("Error loading appointment: $e");
    }
  }

  Future<void> _loadBarberData() async {
    try {
      final doc =
          await BaasClient.collection('users').doc(widget.barberId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          barberAvailability = data['availability'];
          if (data['services'] != null) {
            services = List<Map<String, dynamic>>.from(data['services']);

            // Pre-select logic
            if (widget.initialService != null) {
              final s = services.firstWhere(
                (x) => x['name'] == widget.initialService,
                orElse: () => {},
              );
              if (s.isNotEmpty) selectedServices.add(s);
            }
          }
          if (data['staff'] != null) {
            staffList = List<Map<String, dynamic>>.from(data['staff']);
          }
          isLoading = false;
        });
        _loadBookedSlots();
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadBookedSlots() async {
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final snapshot =
          await BaasClient.collection('appointments')
              .where('barberId', isEqualTo: widget.barberId)
              .where('time', isGreaterThanOrEqualTo: startOfDay)
              .where('time', isLessThan: endOfDay)
              .where('status', isNotEqualTo: 'cancelled')
              .snapshots()
              .first;

      final List<Map<String, dynamic>> booked = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (selectedStaff != null &&
            data['staffId'] != null &&
            data['staffId'] != selectedStaff!['id']) {
          continue;
        }
        final rawTime = data['time'];
        final time =
            rawTime is Timestamp
                ? rawTime.toDate()
                : DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
        booked.add({'time': time, 'duration': data['duration'] ?? 30});
      }
      setState(() {
        bookedSlots = booked;
        selectedSlot = null;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  List<DateTime> _generateSlots() {
    if (barberAvailability == null || selectedServices.isEmpty) return [];
    final startTimeStr =
        (barberAvailability!['startTime'] ?? "10:00").toString();
    final endTimeStr = (barberAvailability!['endTime'] ?? "20:00").toString();
    final startParts = startTimeStr.split(':');
    final endParts = endTimeStr.split(':');
    DateTime current = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );
    final end = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      int.parse(endParts[0]),
      int.parse(endParts[1]),
    );

    int totalDuration = _calculateTotalDuration();
    List<DateTime> slots = [];
    while (current.isBefore(end)) {
      final slotEnd = current.add(Duration(minutes: totalDuration));
      if (slotEnd.isAfter(end)) break;
      if (selectedDate.day == DateTime.now().day &&
          current.isBefore(DateTime.now())) {
        current = current.add(const Duration(minutes: 30));
        continue;
      }

      bool overlap = false;
      for (var booked in bookedSlots) {
        final DateTime bStart = booked['time'];
        final DateTime bEnd = bStart.add(Duration(minutes: booked['duration']));
        if (current.isBefore(bEnd) && slotEnd.isAfter(bStart)) {
          overlap = true;
          break;
        }
      }
      if (!overlap) slots.add(current);
      current = current.add(const Duration(minutes: 30)); // 30min steps
    }
    return slots;
  }

  double _calculateTotalPrice() {
    double total = 0;
    for (var s in selectedServices) {
      if (s.containsKey('selectedVariant')) {
        total +=
            (double.tryParse(s['selectedVariant']['price'].toString()) ?? 0);
      } else {
        total +=
            (double.tryParse(s['price'].toString().replaceAll('*', '')) ?? 0);
      }
    }
    return total;
  }

  int _calculateTotalDuration() {
    int total = 0;
    for (var s in selectedServices) {
      if (s.containsKey('selectedVariant')) {
        total += (s['selectedVariant']['duration'] as int? ?? 30);
      } else {
        total += (s['duration'] as int? ?? 30);
      }
    }
    return total > 0 ? total : 30;
  }

  void _showVariantSelection(Map<String, dynamic> service) {
    final List variants = service['variants'] ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Choose Style for ${service['name']}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...variants.map(
                  (v) => ListTile(
                    title: Text(
                      v['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      "₹${v['price']}",
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                    onTap: () {
                      setState(() {
                        final copy = Map<String, dynamic>.from(service);
                        copy['selectedVariant'] = v;
                        selectedServices.add(copy);
                        _loadBookedSlots();
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _confirmBooking({String paymentStatus = 'pending'}) async {
    if (selectedServices.isEmpty || selectedSlot == null) return;
    setState(() => isBooking = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('userId');
      final customerName = prefs.getString('userName') ?? 'Customer';
      if (customerId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login')));
        setState(() => isBooking = false);
        return;
      }

      // FINAL COLLISION CHECK: Is this slot still free on the server?
      final collisionCheck =
          await BaasClient.collection('appointments')
              .where('barberId', isEqualTo: widget.barberId)
              .where('time', isEqualTo: selectedSlot)
              .where('status', isNotEqualTo: 'cancelled')
              .get();

      if (collisionCheck.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This slot was just booked by someone else!'),
          ),
        );
        _loadBookedSlots(); // Refresh UI
        setState(() => isBooking = false);
        return;
      }

      final appointmentData = {
        'barberId': widget.barberId,
        'barberName': widget.barberName,
        'customerId': customerId,
        'customerName': customerName,
        'service': selectedServices
            .map(
              (s) =>
                  s.containsKey('selectedVariant')
                      ? "${s['name']} (${s['selectedVariant']['name']})"
                      : s['name'],
            )
            .join(", "),
        'price': _calculateTotalPrice() - _discountAmount,
        'duration': _calculateTotalDuration(),
        'time': selectedSlot,
        'staffId': selectedStaff?['id'],
        'status': 'confirmed',
        'isDone': false,
        'paymentStatus': paymentStatus,
        'specialNotes': _specialNotes,
        'referencePhoto': _referencePhotoUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (widget.rescheduleAppointmentId != null) {
        await BaasClient.collection(
          'appointments',
        ).doc(widget.rescheduleAppointmentId!).update(appointmentData);
      } else {
        appointmentData['createdAt'] = DateTime.now().toIso8601String();
        await BaasClient.collection('appointments').add(appointmentData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.rescheduleAppointmentId != null
                  ? 'Appointment Rescheduled!'
                  : 'Confirmed!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    setState(() => isBooking = false);
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateSlots();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.barberName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                children: [
                  _buildDateSelector(),
                  if (staffList.isNotEmpty) _buildStaffSelector(),
                  _buildServiceSelection(),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Divider(color: Colors.white10),
                  ),
                  _buildSpecialRequests(),
                  const SizedBox(height: 20),
                  _buildSlotsGrid(slots),
                  const SizedBox(height: 100),
                ],
              ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (ctx, i) {
          final d = DateTime.now().add(Duration(days: i));
          final sel = d.day == selectedDate.day;
          return GestureDetector(
            onTap:
                () => setState(() {
                  selectedDate = d;
                  _loadBookedSlots();
                }),
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: sel ? Colors.greenAccent : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${d.day}",
                    style: TextStyle(
                      color: sel ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    [
                      "Mon",
                      "Tue",
                      "Wed",
                      "Thu",
                      "Fri",
                      "Sat",
                      "Sun",
                    ][d.weekday - 1],
                    style: TextStyle(
                      color: sel ? Colors.black : Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaffSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "PROFESSIONAL",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildStaffItem(null),
              ...staffList.map((s) => _buildStaffItem(s)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffItem(Map<String, dynamic>? staff) {
    bool sel = selectedStaff == staff;
    return GestureDetector(
      onTap:
          () => setState(() {
            selectedStaff = staff;
            _loadBookedSlots();
          }),
      child: Container(
        width: 60,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: sel ? Colors.greenAccent : Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              staff == null ? Icons.group_outlined : Icons.person_outline,
              size: 20,
              color: sel ? Colors.black : Colors.white,
            ),
            Text(
              staff?['name'] ?? "Any",
              style: TextStyle(
                color: sel ? Colors.black : Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSelection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children:
            services.map((s) {
              bool sel = selectedServices.any((x) => x['name'] == s['name']);
              bool hasV = (s['variants'] as List?)?.isNotEmpty ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(s['name']),
                  backgroundColor: sel ? Colors.greenAccent : Colors.white10,
                  labelStyle: TextStyle(
                    color: sel ? Colors.black : Colors.white,
                    fontSize: 12,
                  ),
                  onPressed: () {
                    if (sel) {
                      setState(
                        () => selectedServices.removeWhere(
                          (x) => x['name'] == s['name'],
                        ),
                      );
                    } else if (hasV) {
                      _showVariantSelection(s);
                    } else {
                      setState(() => selectedServices.add(s));
                      _loadBookedSlots();
                    }
                  },
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSpecialRequests() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SPECIAL REQUESTS",
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => _specialNotes = v,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Notes...",
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap:
                () => setState(
                  () =>
                      _referencePhotoUrl =
                          "https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500",
                ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    _referencePhotoUrl != null
                        ? Colors.greenAccent.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                border: Border.all(
                  color:
                      _referencePhotoUrl != null
                          ? Colors.greenAccent
                          : Colors.white12,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _referencePhotoUrl != null
                        ? Icons.check
                        : Icons.camera_alt_outlined,
                    color:
                        _referencePhotoUrl != null
                            ? Colors.greenAccent
                            : Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _referencePhotoUrl != null
                        ? "Photo attached"
                        : "Attach reference photo",
                    style: TextStyle(
                      color:
                          _referencePhotoUrl != null
                              ? Colors.greenAccent
                              : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsGrid(List<DateTime> slots) {
    if (slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            selectedServices.isEmpty
                ? "Please select a service above to see available slots"
                : "No slots available for the selected services/date",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: slots.length,
      itemBuilder: (ctx, i) {
        final s = slots[i];
        bool sel = selectedSlot == s;
        return GestureDetector(
          onTap: () => setState(() => selectedSlot = s),
          child: Container(
            decoration: BoxDecoration(
              color: sel ? Colors.greenAccent : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                TimeOfDay.fromDateTime(s).format(ctx),
                style: TextStyle(
                  color: sel ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    if (isLoading || selectedSlot == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ElevatedButton(
        onPressed:
            isBooking ? null : () => _confirmBooking(paymentStatus: 'cash'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            isBooking
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
                : Text(
                  "Confirm Appointment (₹${_calculateTotalPrice() - _discountAmount})",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }
}
