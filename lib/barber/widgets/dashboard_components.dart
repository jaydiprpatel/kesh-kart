import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/backend/loyalty_service.dart';
import 'package:kesh_kart/backend/referral_service.dart';
import '../../commons.dart';
import '../customer_profile.dart';
import '../earnings.dart';
import '../notifications.dart';
import '../../customer/chat_inbox.dart';
import '../products.dart';
import '../profile.dart';
import '../reviews.dart';
import '../staff.dart';
import '../coupons.dart';
import '../portfolio.dart';
import '../appointment_history.dart';
import '../manage_availability.dart';
import '../service.dart';
import 'dart:ui';

// --- UTILS ---
Widget _buildLockedOverlay({
  required Widget child,
  bool isLocked = true,
  String message = "Verification Required",
}) {
  if (!isLocked) return child;
  return Stack(
    children: [
      Opacity(opacity: 0.3, child: AbsorbPointer(child: child)),
      Positioned.fill(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                color: Colors.orangeAccent,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// --- EARNINGS CARD ---

class EarningsSummaryCard extends StatefulWidget {
  final String barberId;
  final String verificationStatus;
  const EarningsSummaryCard({
    super.key,
    required this.barberId,
    this.verificationStatus = 'unverified',
  });

  @override
  State<EarningsSummaryCard> createState() => _EarningsSummaryCardState();
}

class _EarningsSummaryCardState extends State<EarningsSummaryCard> {
  String _earningsRange = 'Today';
  Stream<dynamic>? _stream;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  @override
  void didUpdateWidget(EarningsSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.barberId != oldWidget.barberId) {
      _updateStream();
    }
  }

  void _updateStream() {
    if (widget.barberId.isEmpty) return; // Wait for ID
    final now = DateTime.now();
    if (_earningsRange == 'Week') {
      _startDate = now.subtract(const Duration(days: 7));
      _endDate = now;
    } else if (_earningsRange == 'Month') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
    } else {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = _startDate!.add(const Duration(days: 1));
    }

    _stream =
        BaasClient.collection('appointments')
            .where('barberId', isEqualTo: widget.barberId)
            .where('time', isGreaterThanOrEqualTo: _startDate)
            .where('time', isLessThan: _endDate)
            .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return _buildLockedOverlay(
      isLocked: widget.verificationStatus != 'approved',
      message: "Verify to see Earnings",
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            slideUpRoute(BarberEarningsScreen(barberId: widget.barberId)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Earnings',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Row(
                    children:
                        ['Today', 'Week', 'Month'].map((range) {
                          final isSelected = _earningsRange == range;
                          return GestureDetector(
                            onTap: () {
                              if (_earningsRange != range) {
                                setState(() {
                                  _earningsRange = range;
                                  _updateStream();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFF00D189)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? const Color(0xFF00D189)
                                          : Colors.white24,
                                ),
                              ),
                              child: Text(
                                range,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.black : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder(
                stream: _stream,
                builder: (context, snapshot) {
                  double totalEarnings = 0;
                  int completedCount = 0;

                  if (snapshot.hasData) {
                    final docs = (snapshot.data as dynamic).docs;
                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['isDone'] == true ||
                          data['status'] == 'completed') {
                        completedCount++;
                        var price = data['price'];
                        if (price != null) {
                          if (price is num) {
                            totalEarnings += price.toDouble();
                          } else if (price is String) {
                            String cleanPrice = price.replaceAll(
                              RegExp(r'[^0-9.]'),
                              '',
                            );
                            totalEarnings += double.tryParse(cleanPrice) ?? 0;
                          }
                        }
                      }
                    }
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹ ${totalEarnings.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: Color(0xFF00D189),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Total Income',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white12,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$completedCount',
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Appointments',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_earningsRange == 'Today') ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Today's Goal",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "₹${totalEarnings.toInt()} / ₹5000",
                              style: const TextStyle(
                                color: Color(0xFF00D189),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (totalEarnings / 5000).clamp(0.0, 1.0),
                            backgroundColor: Colors.white10,
                            color: const Color(0xFF00D189),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PENDING REQUESTS ---

class PendingRequestsSection extends StatefulWidget {
  final String barberId;
  final String verificationStatus;
  const PendingRequestsSection({
    super.key,
    required this.barberId,
    this.verificationStatus = 'unverified',
  });

  @override
  State<PendingRequestsSection> createState() => _PendingRequestsSectionState();
}

class _PendingRequestsSectionState extends State<PendingRequestsSection> {
  Stream<dynamic>? _stream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  @override
  void didUpdateWidget(PendingRequestsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.barberId != oldWidget.barberId) {
      _updateStream();
    }
  }

  void _updateStream() {
    if (widget.barberId.isEmpty) return;
    _stream =
        BaasClient.collection(
          'appointments',
        ).where('barberId', isEqualTo: widget.barberId).snapshots();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _buildLockedOverlay(
      isLocked: widget.verificationStatus != 'approved',
      message: "Verify to manage Requests",
      child: StreamBuilder(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: List.generate(2, (index) => const ShimmerListTile()),
            );
          }
          if (!snapshot.hasData) return const SizedBox();
          final docs = (snapshot.data as dynamic).docs as List;

          // Client-side filter: only show appointments that are NOT done and NOT cancelled
          final pendingDocs =
              docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status']?.toString().toLowerCase() ?? '';
                final isDone = data['isDone'] == true;
                return !isDone &&
                    status != 'cancelled' &&
                    status != 'completed' &&
                    status != 'rejected';
              }).toList();

          if (pendingDocs.isEmpty) return const SizedBox();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Upcoming Appointments (${pendingDocs.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              ...pendingDocs.map<Widget>((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final rawTime = data['time'];
                final time =
                    rawTime is DateTime
                        ? rawTime
                        : (rawTime is Timestamp
                            ? rawTime.toDate()
                            : (DateTime.tryParse(rawTime.toString()) ??
                                DateTime.now()));

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D189).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00D189).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (data['customerId'] != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => BarberCustomerProfileScreen(
                                          barberId: widget.barberId,
                                          customerId: data['customerId'],
                                          customerName:
                                              data['customerName'] ?? 'Unknown',
                                        ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              data['customerName'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            "${time.day}/${time.month} • ${TimeOfDay.fromDateTime(time).format(context)}",
                            style: const TextStyle(
                              color: Color(0xFF00D189),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            data['service'] ?? 'No service',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      if (data['specialNotes'] != null &&
                          data['specialNotes'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notes,
                                size: 14,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  data['specialNotes'],
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (data['referencePhoto'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: GestureDetector(
                            onTap: () {
                              // Full screen image viewer could go here
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                data['referencePhoto'],
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const SizedBox(),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  (widget.verificationStatus != 'approved')
                                      ? null
                                      : () async {
                                        await BaasClient.collection(
                                          'appointments',
                                        ).doc(doc.id).update({
                                          'isDone': true,
                                          'status': 'completed',
                                        });
                                        if (data['customerId'] != null) {
                                          await LoyaltyService.incrementPoints(
                                            data['customerId'],
                                            widget.barberId,
                                          );
                                        }
                                        // Trigger referral reward for inviter if this is the barber's first COMPLETED job
                                        await ReferralService.processBarberFirstAppointment(
                                          widget.barberId,
                                        );
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00D189),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.white10,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text("Done"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton(
                              onPressed:
                                  () => _showRescheduleDialog(
                                    context,
                                    doc.id,
                                    time,
                                  ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF00D189),
                              ),
                              child: const Text("Reschedule"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () => _showCancelDialog(context, doc.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

// --- TOP SERVICES ---

class TopServicesSection extends StatelessWidget {
  final String barberId;
  const TopServicesSection({super.key, required this.barberId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream:
          BaasClient.collection(
            'appointments',
          ).where('barberId', isEqualTo: barberId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final allDocs = (snapshot.data as dynamic).docs;

        // Client-side filtering
        final docs =
            allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'completed' || data['isDone'] == true;
            }).toList();

        if (docs.isEmpty) return const SizedBox();

        final Map<String, int> serviceCounts = {};
        for (var doc in docs) {
          final service = doc.data()['service'] as String? ?? 'Other';
          serviceCounts[service] = (serviceCounts[service] ?? 0) + 1;
        }

        final sortedServices =
            serviceCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        final topServices = sortedServices.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Popular Services',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children:
                    topServices.map((entry) {
                      final isLast = topServices.last == entry;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${entry.value} bookings',
                                  style: const TextStyle(
                                    color: Color(0xFF00D189),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.trending_up,
                                  color: Color(0xFF00D189),
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// --- APPOINTMENTS LIST ---

class DashboardAppointmentsList extends StatefulWidget {
  final String barberId;
  final DateTime selectedDate;
  final String verificationStatus;
  const DashboardAppointmentsList({
    super.key,
    required this.barberId,
    required this.selectedDate,
    this.verificationStatus = 'unverified',
  });

  @override
  State<DashboardAppointmentsList> createState() =>
      _DashboardAppointmentsListState();
}

class _DashboardAppointmentsListState extends State<DashboardAppointmentsList> {
  Stream<dynamic>? _stream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  @override
  void didUpdateWidget(DashboardAppointmentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate ||
        widget.barberId != oldWidget.barberId) {
      _updateStream();
    }
  }

  void _updateStream() {
    if (widget.barberId.isEmpty) return;
    final start = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final end = start.add(const Duration(days: 1));

    _stream =
        BaasClient.collection('appointments')
            .where('barberId', isEqualTo: widget.barberId)
            .where('time', isGreaterThanOrEqualTo: start)
            .where('time', isLessThan: end)
            .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return _buildLockedOverlay(
      isLocked: widget.verificationStatus != 'approved',
      message: "Verify to manage Schedule",
      child: StreamBuilder(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: List.generate(3, (index) => const ShimmerListTile()),
            );
          }
          if (!snapshot.hasData) return const SizedBox();
          final docs = (snapshot.data as dynamic).docs;
          final filteredDocs =
              docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status']?.toString().toLowerCase() ?? '';
                final isDone = data['isDone'] == true;
                return status != 'pending' &&
                    !isDone &&
                    status != 'completed' &&
                    status != 'cancelled' &&
                    status != 'rejected';
              }).toList();

          if (filteredDocs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 48,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No appointments for this day',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return Column(
            children:
                filteredDocs.map<Widget>((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final displayStatus =
                      (data['status']?.toString().toLowerCase() ?? '');
                  final isCancelled =
                      displayStatus == 'cancelled' ||
                      displayStatus == 'rejected';
                  final rawTime = data['time'];
                  final time =
                      rawTime is DateTime
                          ? rawTime
                          : (rawTime is Timestamp
                              ? rawTime.toDate()
                              : (DateTime.tryParse(rawTime.toString()) ??
                                  DateTime.now()));

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
                        color: const Color(0xFF00D189).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              data['customerName'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              TimeOfDay.fromDateTime(time).format(context),
                              style: const TextStyle(
                                color: Color(0xFF00D189),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['service'] ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        if (!isCancelled)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      (widget.verificationStatus != 'approved')
                                          ? null
                                          : () async {
                                            await BaasClient.collection(
                                              'appointments',
                                            ).doc(doc.id).update({
                                              'isDone': true,
                                              'status': 'completed',
                                            });
                                            if (data['customerId'] != null) {
                                              await LoyaltyService.incrementPoints(
                                                data['customerId'],
                                                widget.barberId,
                                              );
                                            }
                                            // Trigger referral reward for inviter if this is the barber's first COMPLETED job
                                            await ReferralService.processBarberFirstAppointment(
                                              widget.barberId,
                                            );
                                          },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        data['isDone'] == true
                                            ? Colors.grey
                                            : const Color(0xFF00D189),
                                    foregroundColor: Colors.black,
                                    disabledBackgroundColor: Colors.white10,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    data['isDone'] == true
                                        ? 'Completed'
                                        : 'Mark as Done',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_calendar,
                                  color: Color(0xFF00D189),
                                ),
                                onPressed:
                                    () => _showRescheduleDialog(
                                      context,
                                      doc.id,
                                      time,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.redAccent,
                                ),
                                onPressed:
                                    () => _showCancelDialog(context, doc.id),
                              ),
                            ],
                          ),
                        if (isCancelled)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'CANCELLED',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}

// --- QUICK ACTIONS ---

class DashboardQuickActions extends StatelessWidget {
  final String barberId;
  const DashboardQuickActions({super.key, required this.barberId});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'icon': Icons.people,
        'label': 'Staff',
        'page': BarberStaffScreen(barberId: barberId),
      },
      {
        'icon': Icons.shopping_bag,
        'label': 'Store',
        'page': BarberProductsScreen(barberId: barberId),
      },
      {
        'icon': Icons.confirmation_num,
        'label': 'Coupons',
        'page': BarberCouponsScreen(barberId: barberId),
      },
      {
        'icon': Icons.photo_library,
        'label': 'Lookbook',
        'page': BarberPortfolioScreen(barberId: barberId),
      },
      {
        'icon': Icons.calendar_month,
        'label': 'History',
        'page': AppointmentHistoryScreen(barberId: barberId),
      },
      {
        'icon': Icons.star,
        'label': 'Reviews',
        'page': BarberReviewsScreen(barberId: barberId),
      },
      {
        'icon': Icons.access_time,
        'label': 'Availability',
        'page': ManageAvailabilityScreen(barberId: barberId),
      },
      {
        'icon': Icons.content_paste,
        'label': 'Menu',
        'page': GroomingMenuScreen(barberId: barberId),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return GestureDetector(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => action['page'] as Widget),
              ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  action['icon'] as IconData,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action['label'] as String,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- DOCK ---

class DashboardQuickActionsDock extends StatefulWidget {
  final String barberId;
  const DashboardQuickActionsDock({super.key, required this.barberId});

  @override
  State<DashboardQuickActionsDock> createState() =>
      _DashboardQuickActionsDockState();
}

class _DashboardQuickActionsDockState extends State<DashboardQuickActionsDock> {
  late Stream<dynamic> _notifStream;

  @override
  void initState() {
    super.initState();
    _notifStream =
        BaasClient.collection('notifications')
            .where('recipientId', isEqualTo: widget.barberId)
            .where('isRead', isEqualTo: false)
            .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StreamBuilder(
                stream: _notifStream,
                builder: (context, snapshot) {
                  bool hasUnread =
                      snapshot.hasData &&
                      (snapshot.data as dynamic).docs.isNotEmpty;
                  return _buildDockIcon(
                    Icons.notifications,
                    "Alerts",
                    hasUnread: hasUnread,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BarberNotificationsScreen(),
                          ),
                        ),
                  );
                },
              ),
              _buildDockIcon(
                Icons.analytics,
                "Earnings",
                onTap:
                    () => Navigator.push(
                      context,
                      slideUpRoute(
                        BarberEarningsScreen(barberId: widget.barberId),
                      ),
                    ),
              ),
              _buildDockIcon(
                Icons.chat,
                "Messages",
                onTap:
                    () => Navigator.push(
                      context,
                      slideUpRoute(const ChatInboxScreen()),
                    ),
              ),
              _buildDockIcon(
                Icons.inventory,
                "Store",
                onTap:
                    () => Navigator.push(
                      context,
                      slideUpRoute(
                        BarberProductsScreen(barberId: widget.barberId),
                      ),
                    ),
              ),
              _buildDockIcon(
                Icons.person,
                "Account",
                onTap:
                    () => Navigator.push(
                      context,
                      slideUpRoute(
                        BarberProfileScreen(barberId: widget.barberId),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockIcon(
    IconData icon,
    String label, {
    required VoidCallback onTap,
    bool hasUnread = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              if (hasUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// --- DIALOGS ---

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
                    style: const TextStyle(color: Color(0xFF00D189)),
                  ),
                  const SizedBox(height: 16),
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
                        selectedColor: const Color(0xFF00D189),
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
                                    ? const Color(0xFF00D189)
                                    : Colors.white24,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);

                      // Ensure initialDate is not before firstDate
                      DateTime initialPickerDate = newDateTime;
                      if (initialPickerDate.isBefore(today)) {
                        initialPickerDate = today;
                      }

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initialPickerDate,
                        firstDate: today,
                        lastDate: today.add(const Duration(days: 30)),
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
                  DropdownButtonFormField<String>(
                    value: selectedReason.isNotEmpty ? selectedReason : null,
                    dropdownColor: Colors.black,
                    decoration: InputDecoration(
                      labelText: "Reason for Reschedule",
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00D189)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items:
                        rescheduleReasons
                            .map(
                              (reason) => DropdownMenuItem(
                                value: reason,
                                child: Text(reason),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => selectedReason = value ?? ''),
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
                          await BaasClient.collection(
                            'appointments',
                          ).doc(appointmentId).update({
                            'time': newDateTime,
                            'rescheduledAt': DateTime.now().toIso8601String(),
                            'reasonForReschedule': selectedReason,
                          });
                          if (context.mounted) Navigator.pop(context);
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
                          style: TextStyle(color: Color(0xFF00D189)),
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
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedReason.isNotEmpty ? selectedReason : null,
                    dropdownColor: Colors.black,
                    decoration: InputDecoration(
                      labelText: "Reason for Cancellation",
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.redAccent),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items:
                        reasons
                            .map(
                              (reason) => DropdownMenuItem(
                                value: reason,
                                child: Text(
                                  reason,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => selectedReason = value ?? ''),
                  ),
                ],
              ),
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
                          await BaasClient.collection(
                            'appointments',
                          ).doc(appointmentId).update({
                            'status': 'cancelled',
                            'cancelledAt': DateTime.now().toIso8601String(),
                            'cancelReason': selectedReason,
                          });
                          if (context.mounted) Navigator.pop(context);
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
