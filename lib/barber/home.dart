import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kesh_kart/barber/profile.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class BarberHome extends StatefulWidget {
  const BarberHome({super.key});

  @override
  _BarberHomeState createState() => _BarberHomeState();
}

class _BarberHomeState extends State<BarberHome> {
  String barberName = '';
  bool isActive = false;
  List<String> shopPhotos = [];
  String barberID = '';
  bool isBarberLoaded = false;

  List<DateTime> upcomingDays = [];
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBarberDetails();

    final today = DateTime.now();
    upcomingDays = List.generate(7, (index) {
      return DateTime(today.year, today.month, today.day + index);
    });
  }

  Future<void> _loadBarberDetails() async {
    final prefs = await SharedPreferences.getInstance();

    barberName = prefs.getString('barberName') ?? 'Barber';
    isActive = prefs.getBool('isActive') ?? false;
    shopPhotos = prefs.getStringList('shopPhotos') ?? [];
    barberID = prefs.getString('userId') ?? '';

    if (mounted) {
      setState(() {
        isBarberLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Hello, $barberName',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),

          actions: [
            Switch(
              value: isActive,
              onChanged: (val) async {
                setState(() => isActive = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isActive', val);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(barberID)
                    .update({'isActive': val});
              },
              activeColor: Colors.green,
              inactiveThumbColor: Colors.grey,
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Text('Active', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            children: [
              _buildEarningsCard(),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSectionTitle('Appointments'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              upcomingDays.map((date) {
                                final isSelected =
                                    date.day == selectedDate.day &&
                                    date.month == selectedDate.month &&
                                    date.year == selectedDate.year;

                                String label;
                                final index = upcomingDays.indexOf(date);
                                if (index == 0) {
                                  label = "Today";
                                } else if (index == 1) {
                                  label = "Tomorrow";
                                } else {
                                  label =
                                      "${date.day} ${_monthName(date.month)}";
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isSelected
                                                ? Colors.black
                                                : Colors.white,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: Colors.greenAccent,
                                    backgroundColor:
                                        Colors
                                            .black, // ← set unselected chip color to black
                                    shape: StadiumBorder(
                                      side: BorderSide(
                                        color:
                                            isSelected
                                                ? Colors.greenAccent
                                                : Colors.white10,
                                      ),
                                    ),
                                    onSelected: (_) {
                                      setState(() {
                                        selectedDate = date;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Appointments List
              Expanded(child: _buildAppointmentsList()),

              const SizedBox(height: 30),
              _buildSectionTitle('Quick Actions'),
              const SizedBox(height: 10),
              _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Today',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            '₹ 1,850',
            style: TextStyle(
              fontSize: 22,
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (!isBarberLoaded || barberID.isEmpty) {
      return Column(
        children: List.generate(2, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.white12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 150, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 100, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(height: 35, width: 120, color: Colors.white),
                ],
              ),
            ),
          );
        }),
      );
    }

    final start = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final end = start.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('appointments')
              .where('barberId', isEqualTo: barberID)
              .where('time', isGreaterThanOrEqualTo: start)
              .where('time', isLessThan: end)
              .orderBy('time')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'No appointments.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return Column(
          children:
              docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isCancelled = data['status'] == 'cancelled';
                final rawTime = data['time'];
                final time =
                    rawTime is Timestamp
                        ? rawTime.toDate()
                        : DateTime.tryParse(rawTime.toString()) ??
                            DateTime.now();

                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isCancelled
                            ? Colors.white10.withOpacity(0.4)
                            : Colors.white10,

                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${data['customerName']} - ${TimeOfDay.fromDateTime(time).format(context)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              if (isCancelled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Cancelled',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          IconButton(
                            onPressed: () {
                              _showCancelDialog(context, doc.id);
                            },
                            icon: const Icon(
                              Icons.cancel,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Cancel Appointment',
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      Text(
                        data['service'],
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 10),
                      if (!isCancelled)
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('appointments')
                                    .doc(doc.id)
                                    .update({'isDone': true});
                                debugPrint(
                                  'Notify customer: ${data['customerId']}',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    data['isDone']
                                        ? Colors.grey
                                        : Colors.greenAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                data['isDone'] ? 'Completed' : 'Mark as Done',
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () {
                                _showRescheduleDialog(context, doc.id, time);
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.greenAccent,
                                ),
                                foregroundColor: Colors.greenAccent,
                              ),
                              child: const Text("Reschedule"),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.person, 'label': 'Profile'},
      {'icon': Icons.build, 'label': 'Services'},
      {'icon': Icons.calendar_month, 'label': 'Appointments'},
      {'icon': Icons.star, 'label': 'Reviews'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () {
            final action = actions[index]['label'];
            if (action == 'Profile') {
              Navigator.push(
                context,
                slideUpRoute(BarberProfileScreen(barberId: barberID)),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    actions[index]['icon'] as IconData,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    actions[index]['label']! as String,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  void _showRescheduleDialog(
    BuildContext context,
    String appointmentId,
    DateTime currentTime,
  ) {
    DateTime newDateTime = currentTime;
    int selectedQuickOption = -1;
    String selectedReason = '';
    bool isLoading = false;

    List<String> rescheduleReasons = [
      "Running Late",
      "Personal Emergency",
      "Customer Request",
      "Power/Network Issue",
      "Other",
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String formattedTime = TimeOfDay.fromDateTime(
              newDateTime,
            ).format(context);
            String formattedDate =
                "${newDateTime.day}/${newDateTime.month}/${newDateTime.year}";

            return AlertDialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Reschedule Appointment',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selected: $formattedDate at $formattedTime',
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                    const SizedBox(height: 16),

                    // Choice Chips for Quick Reschedule
                    Wrap(
                      spacing: 10,
                      children: List.generate(3, (index) {
                        final labels = [
                          'After 1 hour',
                          'After 2 hours',
                          'Tomorrow same time',
                        ];
                        return ChoiceChip(
                          label: Text(labels[index]),
                          selected: selectedQuickOption == index,
                          onSelected: (bool selected) {
                            setState(() {
                              selectedQuickOption = selected ? index : -1;
                              if (selected) {
                                if (index == 0) {
                                  newDateTime = currentTime.add(
                                    const Duration(hours: 1),
                                  );
                                }
                                if (index == 1) {
                                  newDateTime = currentTime.add(
                                    const Duration(hours: 2),
                                  );
                                }
                                if (index == 2) {
                                  newDateTime = currentTime.add(
                                    const Duration(days: 1),
                                  );
                                }
                              }
                            });
                          },
                          selectedColor: Colors.greenAccent,
                          backgroundColor: Colors.black,
                          labelStyle: TextStyle(
                            color:
                                selectedQuickOption == index
                                    ? Colors.black
                                    : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color:
                                  selectedQuickOption == index
                                      ? Colors.greenAccent
                                      : Colors.white24,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Date Picker Styled
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: newDateTime,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedQuickOption = -1;
                            newDateTime = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              newDateTime.hour,
                              newDateTime.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          border: Border.all(color: Colors.white30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pick Date',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time Picker Styled
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(newDateTime),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedQuickOption = -1;
                            newDateTime = DateTime(
                              newDateTime.year,
                              newDateTime.month,
                              newDateTime.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          border: Border.all(color: Colors.white30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.access_time,
                              color: Colors.white70,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pick Time',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dropdown for Reason
                    DropdownButtonFormField<String>(
                      value: selectedReason.isNotEmpty ? selectedReason : null,
                      dropdownColor: Colors.black,
                      decoration: InputDecoration(
                        labelText: "Reason for Reschedule",
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.greenAccent),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items:
                          rescheduleReasons.map((reason) {
                            return DropdownMenuItem(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value ?? '';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed:
                      selectedReason.isEmpty || isLoading
                          ? null
                          : () async {
                            setState(() => isLoading = true);

                            await FirebaseFirestore.instance
                                .collection('appointments')
                                .doc(appointmentId)
                                .update({
                                  'time': newDateTime,
                                  'rescheduledAt': Timestamp.now(),
                                  'reasonForReschedule': selectedReason,
                                });

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Appointment rescheduled"),
                              ),
                            );
                          },
                  child:
                      isLoading
                          ? Shimmer.fromColors(
                            baseColor: Colors.grey[700]!,
                            highlightColor: Colors.white,
                            child: const Text(
                              "Rescheduling...",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )
                          : const Text(
                            'Confirm',
                            style: TextStyle(color: Colors.greenAccent),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCancelDialog(BuildContext context, String appointmentId) {
    String selectedReason = '';
    bool isCancelling = false;

    final reasons = [
      "Customer no-show",
      "Barber unavailable",
      "Double booking",
      "Customer requested cancellation",
      "Other",
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Cancel Appointment',
                style: TextStyle(color: Colors.white),
              ),
              content: DropdownButtonFormField<String>(
                value: selectedReason.isNotEmpty ? selectedReason : null,
                dropdownColor: Colors.black,
                decoration: InputDecoration(
                  labelText: "Reason for Cancellation",
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.redAccent),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                items:
                    reasons.map((reason) {
                      return DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedReason = value ?? '';
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Back',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed:
                      selectedReason.isEmpty || isCancelling
                          ? null
                          : () async {
                            setState(() => isCancelling = true);
                            await FirebaseFirestore.instance
                                .collection('appointments')
                                .doc(appointmentId)
                                .update({
                                  'status': 'cancelled',
                                  'cancelledAt': Timestamp.now(),
                                  'cancelReason': selectedReason,
                                });

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Appointment cancelled"),
                              ),
                            );
                          },
                  child:
                      isCancelling
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.redAccent,
                            ),
                          )
                          : const Text(
                            'Cancel Now',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
