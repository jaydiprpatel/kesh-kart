import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class ManageAvailabilityScreen extends StatefulWidget {
  final String barberId;

  const ManageAvailabilityScreen({super.key, required this.barberId});

  @override
  State<ManageAvailabilityScreen> createState() =>
      _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends State<ManageAvailabilityScreen> {
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  List<int> daysOff = []; // 1=Mon, 7=Sun
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final doc =
          await BaasClient.collection('users').doc(widget.barberId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('availability')) {
          final avail = data['availability'] as Map<String, dynamic>;
          if (avail['startTime'] != null) {
            startTime = _parseTime(avail['startTime']);
          }
          if (avail['endTime'] != null) {
            endTime = _parseTime(avail['endTime']);
          }
          if (avail['daysOff'] != null) {
            daysOff = List<int>.from(avail['daysOff']);
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading availability: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTimeForDb(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isStart
              ? (startTime ?? const TimeOfDay(hour: 9, minute: 0))
              : (endTime ?? const TimeOfDay(hour: 20, minute: 0)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (daysOff.contains(day)) {
        daysOff.remove(day); // Make it Active
      } else {
        daysOff.add(day); // Make it Off
      }
    });
  }

  Future<void> _save() async {
    if (startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please set both Start and End time")),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final availability = {
        'startTime': _formatTimeForDb(startTime!),
        'endTime': _formatTimeForDb(endTime!),
        'daysOff': daysOff,
      };

      await BaasClient.collection(
        'users',
      ).doc(widget.barberId).update({'availability': availability});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Availability Updated!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Shop Availability",
          style: TextStyle(fontFamily: 'Popins', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              )
              : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Set Login/Logout Hours",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Customers can only book appointments within these hours.",
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Time Pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(true),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.greenAccent.withOpacity(0.5),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    "Opens At",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    startTime?.format(context) ?? "--:--",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(false),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.5),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    "Closes At",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    endTime?.format(context) ?? "--:--",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Text(
                      "Weekly Offs",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Select days when your shop is CLOSED.",
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Days Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final dayIndex = index + 1; // 1=Mon
                        final dayName =
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index];
                        final isOff = daysOff.contains(dayIndex);

                        return GestureDetector(
                          onTap: () => _toggleDay(dayIndex),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOff ? Colors.redAccent : Colors.green,
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                dayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Open",
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Closed",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            isSaving
                                ? const CircularProgressIndicator()
                                : const Text(
                                  "Save Availability",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
