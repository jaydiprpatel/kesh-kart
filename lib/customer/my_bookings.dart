import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/customer/select_slot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String customerId = '';
  String customerName = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      customerId = prefs.getString('userId') ?? '';
      customerName = prefs.getString('userName') ?? 'Anonymous';
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submitReview(
    String barberId,
    String appointmentId,
    double rating,
    String comment, {
    String? photoUrl,
  }) async {
    try {
      await BaasClient.collection('reviews').add({
        'barberId': barberId,
        'customerId': customerId,
        'customerName': customerName,
        'appointmentId': appointmentId,
        'rating': rating,
        'comment': comment,
        'photoUrl': photoUrl,
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review Submitted!')));
      }
    } catch (e) {
      debugPrint("Error submitting review: $e");
    }
  }

  void _showRatingDialog(Map<String, dynamic> appointment, String docId) {
    double rating = 5.0;
    String? reviewPhotoUrl;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                "Rate Experience",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Write a comment...",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  if (reviewPhotoUrl != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            reviewPhotoUrl!,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap:
                                () =>
                                    setDialogState(() => reviewPhotoUrl = null),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          reviewPhotoUrl =
                              "https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/200/200";
                        });
                      },
                      icon: const Icon(
                        Icons.add_a_photo,
                        color: Colors.greenAccent,
                      ),
                      label: const Text(
                        "Add Photo of Haircut",
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                  ),
                  onPressed: () {
                    _submitReview(
                      appointment['barberId'],
                      docId,
                      rating,
                      commentController.text,
                      photoUrl: reviewPhotoUrl,
                    );
                  },
                  child: const Text(
                    "Submit",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelBooking(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              "Cancel Appointment",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "Are you sure you want to cancel this booking?",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Keep it"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Cancel Appointment",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await BaasClient.collection(
          'appointments',
        ).doc(docId).update({'status': 'cancelled'});
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Booking Cancelled")));
        }
      } catch (e) {
        debugPrint("Error cancelling booking: $e");
      }
    }
  }

  void _manageBooking(Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                "Manage Appointment",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D189).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF00D189),
                    size: 18,
                  ),
                ),
                title: const Text(
                  "Reschedule",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  "Change your date or time slot",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(
                      builder:
                          (_) => SelectSlotScreen(
                            barberId: data['barberId'],
                            barberName: data['barberName'] ?? "Barber",
                            rescheduleAppointmentId: docId,
                          ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white10, height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
                title: const Text(
                  "Cancel Booking",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  "Refund might take 2-3 business days",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _cancelBooking(docId);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "My Bookings",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00D189),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFF00D189),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [Tab(text: "Upcoming"), Tab(text: "History")],
        ),
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D189)),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(upcoming: true),
                  _buildList(upcoming: false),
                ],
              ),
    );
  }

  Widget _buildList({required bool upcoming}) {
    return StreamBuilder(
      stream:
          BaasClient.collection(
            'appointments',
          ).where('customerId', isEqualTo: customerId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D189)),
          );
        }

        if (!snapshot.hasData || (snapshot.data as dynamic).docs.isEmpty) {
          return _buildEmptyState(upcoming);
        }

        final allDocs = (snapshot.data as dynamic).docs;
        final now = DateTime.now();
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status =
              (data['status']?.toString().toLowerCase() ?? 'pending');
          final time = _parseTime(data['time']);
          final isPast = time.isBefore(now);

          if (upcoming) {
            return (status == 'pending' || status == 'confirmed') && !isPast;
          } else {
            return status == 'completed' ||
                status == 'cancelled' ||
                status == 'rejected' ||
                isPast;
          }
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState(upcoming);
        }

        filteredDocs.sort((a, b) {
          final tA = _parseTime(a.data()['time']);
          final tB = _parseTime(b.data()['time']);
          return upcoming ? tA.compareTo(tB) : tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final time = _parseTime(data['time']);
            final status =
                (data['status']?.toString().toLowerCase() ?? 'pending');

            return _buildBookingCard(data, doc.id, time, status, upcoming);
          },
        );
      },
    );
  }

  DateTime _parseTime(dynamic rawTime) {
    if (rawTime is Timestamp) return rawTime.toDate();
    return DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
  }

  Widget _buildEmptyState(bool upcoming) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            upcoming ? Icons.calendar_today_outlined : Icons.history,
            size: 64,
            color: Colors.white10,
          ),
          const SizedBox(height: 16),
          Text(
            upcoming ? "No upcoming bookings" : "No booking history",
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
    Map<String, dynamic> data,
    String docId,
    DateTime time,
    String status,
    bool upcoming,
  ) {
    final isCompleted = status == 'completed';
    final isConfirmed = status == 'confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isConfirmed
                  ? const Color(0xFF00D189).withOpacity(0.3)
                  : Colors.white10,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder(
                      future:
                          BaasClient.collection(
                            'users',
                          ).doc(data['barberId']).get(),
                      builder: (context, snapshot) {
                        String? img;
                        if (snapshot.hasData &&
                            (snapshot.data as dynamic).exists) {
                          final bData = (snapshot.data as dynamic).data();
                          if (bData != null &&
                              bData['shopPhotos'] != null &&
                              (bData['shopPhotos'] as List).isNotEmpty) {
                            img = bData['shopPhotos'][0];
                          }
                        }
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            image:
                                img != null
                                    ? DecorationImage(
                                      image: NetworkImage(img),
                                      fit: BoxFit.cover,
                                    )
                                    : null,
                          ),
                          child:
                              img == null
                                  ? const Icon(
                                    Icons.store,
                                    color: Colors.white24,
                                  )
                                  : null,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['barberName'] ?? 'Barber Shop',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            data['service'] ?? 'Service',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF00D189),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.access_time,
                      TimeOfDay.fromDateTime(time).format(context),
                    ),
                    const SizedBox(width: 20),
                    _buildInfoItem(
                      Icons.calendar_month,
                      "${time.day}/${time.month}/${time.year}",
                    ),
                    const Spacer(),
                    Text(
                      "₹${data['price']}",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (upcoming) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _manageBooking(data, docId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Manage Appointment"),
                    ),
                  ),
                ],
                if (!upcoming && isCompleted) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRatingDialog(data, docId),
                      icon: const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 18,
                      ),
                      label: const Text(
                        "Rate Experience",
                        style: TextStyle(color: Colors.amber),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amber),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF00D189);
      case 'pending':
        return Colors.orangeAccent;
      case 'completed':
        return Colors.blueAccent;
      case 'cancelled':
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
