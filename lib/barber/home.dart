import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/barber/subscription_screen.dart';
import 'package:kesh_kart/barber/reviews.dart';
import 'package:kesh_kart/barber/widgets/dashboard_components.dart';
import 'package:kesh_kart/barber/pro_dashboard.dart';
import 'package:kesh_kart/barber/barber_verification.dart';
import 'package:kesh_kart/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int refreshKey = 0;
  String currentStatus = 'Available';
  String verificationStatus = 'unverified';
  String subscriptionStatus = 'none';
  bool proAccessActive = false;

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

    // Ensure SDK session is active (Sync with AuthProvider)
    if (!BaasClient.instance.sdk.auth.isAuthenticated) {
      debugPrint("⚠️ Auth Desync Detected in BarberHome. Redirecting to Login.");
      await prefs.setBool('isLoggedIn', false);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LogInScreen()),
          (route) => false,
        );
      }
      return;
    }

    barberName = prefs.getString('barberName') ?? 'Barber';
    isActive = prefs.getBool('isActive') ?? false;
    shopPhotos = prefs.getStringList('shopPhotos') ?? [];
    barberID = prefs.getString('userId') ?? '';
    currentStatus = prefs.getString('liveStatus') ?? 'Available';

    try {
      final userSnap = await BaasClient.collection('users').doc(barberID).get();
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.data() as Map<String, dynamic>);
        verificationStatus = userData['verificationStatus'] ?? 'unverified';
        subscriptionStatus = userData['subscriptionStatus'] ?? 'none';
        proAccessActive = userData['proAccessActive'] == true;
      }
    } catch (e) {
      debugPrint("Error loading verification status: $e");
    }

    if (mounted) {
      setState(() {
        isBarberLoaded = true;
      });
    }
  }

  Future<void> _openSubscriptionFlow() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    if (result == true) {
      await _loadBarberDetails();
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
          title: const Text(
            'Barber Dashboard',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Business Insights',
              icon: const Icon(
                Icons.analytics_outlined,
                color: Colors.greenAccent,
              ),
              onPressed: () {
                if (!proAccessActive) {
                  _openSubscriptionFlow();
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProDashboardScreen(barberId: barberID),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.star_outline, color: Colors.yellowAccent),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BarberReviewsScreen(barberId: barberID),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.circle,
                size: 14,
                color: _getLiveStatusColor(currentStatus),
              ),
              onSelected: (String status) async {
                setState(() => currentStatus = status);
                await BaasClient.collection('users').doc(barberID).update({
                  'liveStatus': status,
                  'isActive': status != 'Away',
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('liveStatus', status);
                await prefs.setBool('isActive', status != 'Away');
              },
              itemBuilder:
                  (context) => [
                    _buildStatusItem('Available', Colors.green),
                    _buildStatusItem('Busy', Colors.amber),
                    _buildStatusItem('Away', Colors.grey),
                  ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                currentStatus,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await _loadBarberDetails();
                setState(() {
                  refreshKey++;
                });
              },
              backgroundColor: Colors.black,
              color: const Color(0xFF00D189),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  children: [
                    _buildVerificationNudge(),
                    _buildSubscriptionNudge(),
                    EarningsSummaryCard(
                      key: ValueKey('earnings_$refreshKey'),
                      barberId: barberID,
                      verificationStatus: verificationStatus,
                    ),
                    const SizedBox(height: 20),
                    TopServicesSection(
                      key: ValueKey('services_$refreshKey'),
                      barberId: barberID,
                    ),
                    const SizedBox(height: 20),
                    PendingRequestsSection(
                      key: ValueKey('pending_$refreshKey'),
                      barberId: barberID,
                      verificationStatus: verificationStatus,
                    ),
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
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
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
                                          selectedColor: const Color(
                                            0xFF00D189,
                                          ),
                                          backgroundColor:
                                              Colors
                                                  .black, // ← set unselected chip color to black
                                          shape: StadiumBorder(
                                            side: BorderSide(
                                              color:
                                                  isSelected
                                                      ? const Color(0xFF00D189)
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
                    DashboardAppointmentsList(
                      key: ValueKey('appointments_$refreshKey'),
                      barberId: barberID,
                      selectedDate: selectedDate,
                      verificationStatus: verificationStatus,
                    ),

                    const SizedBox(height: 30),
                    _buildSectionTitle('Quick Actions'),
                    const SizedBox(height: 10),
                    DashboardQuickActions(barberId: barberID),
                    const SizedBox(height: 100), // Space for dock
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: DashboardQuickActionsDock(barberId: barberID),
            ),
          ],
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

  Color _getLiveStatusColor(String status) {
    if (status == 'Available') return Colors.green;
    if (status == 'Busy') return Colors.amber;
    return Colors.grey;
  }

  PopupMenuItem<String> _buildStatusItem(String status, Color color) {
    return PopupMenuItem(
      value: status,
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(status, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildVerificationNudge() {
    if (verificationStatus == 'approved') return const SizedBox.shrink();

    bool isPending = verificationStatus == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isPending
                  ? [
                    Colors.blue.withOpacity(0.2),
                    Colors.blue.withOpacity(0.05),
                  ]
                  : [
                    Colors.orange.withOpacity(0.2),
                    Colors.orange.withOpacity(0.05),
                  ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isPending
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isPending ? Icons.hourglass_empty : Icons.warning_amber_rounded,
                color: isPending ? Colors.blueAccent : Colors.orangeAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending
                          ? "Verification Pending"
                          : "Verification Required",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPending
                          ? "We're reviewing your shop details. This usually takes less than 24 hours."
                          : "Verify your shop to start accepting bookings and unlock rewards.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isPending) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => BarberVerificationScreen(barberId: barberID),
                  ),
                );
                if (result == true) {
                  _loadBarberDetails();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Verify Shop Now",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionNudge() {
    if (verificationStatus != 'approved' || proAccessActive) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D189).withOpacity(0.18),
            Colors.black.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D189).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: Color(0xFF00D189)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Subscription Required",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Your shop is verified, but customers will only see you after Pro access is active.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _openSubscriptionFlow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D189),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Activate Pro Subscription",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
