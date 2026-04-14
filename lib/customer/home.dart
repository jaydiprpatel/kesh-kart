// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/backend/baas_snapshot.dart';
import 'package:kesh_kart/customer/barber_profile.dart'; // Import Profile Screen
import 'package:kesh_kart/customer/my_bookings.dart';
import 'package:kesh_kart/backend/baas_query_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kesh_kart/customer/city_search.dart';
import 'package:kesh_kart/customer/all_barbers.dart';
import 'package:kesh_kart/customer/profile_settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:kesh_kart/backend/heuristic_service.dart';
import 'package:kesh_kart/models/hairstyle.dart';
import 'package:kesh_kart/repositories/hairstyle_repository.dart';
import 'package:kesh_kart/customer/widgets/hairstyle_card.dart';
import 'package:kesh_kart/customer/hairstyle_details_screen.dart';
import 'package:kesh_kart/models/radar_barber.dart';
import 'package:kesh_kart/services/barber_service.dart';
import 'package:kesh_kart/customer/widgets/premium_barber_carousel.dart';
import 'package:kesh_kart/customer/screens/ai_styler_screen.dart';
import 'package:kesh_kart/customer/screens/style_match_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _currentCity = "Vadodara";
  String _currentPincode = "390001";
  String _userName = "User";
  double? _userLat;
  double? _userLng;
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  String? _userId;
  List<String> _visitedBarberIds = [];
  List<String> _favoriteBarberIds = [];
  bool _nudgeDismissed = false;
  Map<String, dynamic>? _lastSeenProfile;
  StreamSubscription<dynamic>? _appointmentSubscription;

  // Stream/Future variables for performance stabilization
  Stream<BaasQuerySnapshot>? _inspirationStream;
  Stream<BaasQuerySnapshot>? _upcomingBookingStream;
  Future<Map<String, dynamic>>? _nudgeInsightsFuture;
  List<Map<String, dynamic>> _historyInsights = [];
  bool _historyLoaded = false;

  final BarberService _barberService = BarberService();
  List<RadarBarber> _radarBarbers = [];
  bool _isAiCardDismissed = false;
  bool _hasOnboardedToBarber =
      true; // Default to true to prevent accidental guests redirects

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _initUserListener();
    _checkUpcomingReminders();
  }

  Future<void> _initUserListener() async {
    final prefs = await SharedPreferences.getInstance();
    String? uId = prefs.getString('userId');
    final uName = prefs.getString('userName');

    if ((uId == null || uId.isEmpty) &&
        BaasClient.instance.sdk.auth.currentUser != null) {
      uId = BaasClient.instance.sdk.auth.currentUser!.id;
      await prefs.setString('userId', uId);
    }

    if (uId != null && uId.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userId = uId;
          if (uName != null) _userName = uName;
        });
      }

      // Fetch history immediately to drive AI Card dismissal
      _loadHistory(uId);

      _initPersistentStreams();

      // Persistent user profile sync (Updates Favorites and Profile completion)
      BaasClient.collection('users').doc(uId).snapshots().listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data();
          setState(() {
            _userName = data['name'] ?? _userName;
            _favoriteBarberIds = List<String>.from(
              data['favoriteBarbers'] ?? [],
            );
            _lastSeenProfile = data;
          });

          // 🚀 FIRST-TIME REDIRECTION LOGIC
          if (_favoriteBarberIds.isEmpty &&
              _visitedBarberIds.isEmpty &&
              !_hasOnboardedToBarber) {
            _triggerOnboardingSearch();
          }
        }
      });
    }
  }

  Future<void> _triggerOnboardingSearch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded_to_barber', true);
    if (mounted) {
      setState(() => _hasOnboardedToBarber = true);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AllBarbersPage()),
      );
    }
  }

  Future<void> _loadHistory(String uId) async {
    try {
      final insights = await HeuristicService.getMultiGroomingInsights(uId);
      if (mounted) {
        setState(() {
          _historyInsights = insights;
          _historyLoaded = true;
          if (insights.isNotEmpty) {
            _visitedBarberIds =
                insights.map((e) => e['barberId'].toString()).toList();
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }

  Future<void> _checkUpcomingReminders() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final uId = prefs.getString('userId') ?? '';
    if (uId.isEmpty) return;

    try {
      final snapshot =
          await BaasClient.collection('appointments')
              .where('customerId', isEqualTo: uId)
              .where('status', isEqualTo: 'confirmed')
              .where('isDone', isEqualTo: false)
              .limit(1)
              .get();

      final docs = (snapshot as dynamic).docs;
      if (docs.isNotEmpty && mounted) {
        if (!context.mounted) return;
        final data = docs.first.data();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Reminder: Appointment at ${data['barberName'] ?? 'KeshKart'} soon!",
            ),
            backgroundColor: const Color(0xFF00D189),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking reminders: $e");
    }
  }

  Future<void> _loadLocation() async {
    final prefs = await SharedPreferences.getInstance();

    // Load flags first so they are ready for the initial build/refresh
    if (mounted) {
      setState(() {
        _hasOnboardedToBarber = prefs.getBool('onboarded_to_barber') ?? false;
        _isAiCardDismissed = prefs.getBool('is_ai_card_dismissed') ?? false;
      });
    }

    String? city = prefs.getString('userCity');
    String? pincode = prefs.getString('userPincode');
    double? lat = prefs.getDouble('lat');
    double? lng = prefs.getDouble('lng');

    if (city == null || pincode == null || lat == null || lng == null) {
      _requestLocationAndDetect();
    } else {
      if (mounted) {
        final String? sdkId = BaasClient.instance.sdk.auth.currentUser?.id;
        final String? prefsId = prefs.getString('userId');

        setState(() {
          _currentCity = city;
          _currentPincode = pincode;
          _userLat = lat;
          _userLng = lng;
          // Sync prefs with SDK if mismatch
          _userId = sdkId ?? prefsId;
          if (_userId != prefsId && _userId != null) {
            prefs.setString('userId', _userId!);
            debugPrint(
              "[DIAGNOSTIC] Home -> Syncing local SharedPreferences with SDK session: $_userId",
            );
          }
        });

        // CRITICAL: Force identity recovery if something seems off
        _recoverIdentityByPhone();
      }
      _initPersistentStreams();
      _fetchRadarBarbers();
    }
  }

  Future<void> _recoverIdentityByPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone');
    if (phone == null || phone.isEmpty) return;

    try {
      debugPrint("[IDENTITY] Scanning for document anchored to phone: $phone");
      final snapshot =
          await BaasClient.collection(
            'users',
          ).where('phone', isEqualTo: phone).get();

      final docs = (snapshot as dynamic).docs as List;
      if (docs.isNotEmpty) {
        final recoveredId = docs.first.id;
        if (recoveredId != _userId) {
          debugPrint(
            "[IDENTITY] Repairing identity! Found correct document ID: $recoveredId",
          );
          await prefs.setString('userId', recoveredId);
          if (mounted) {
            setState(() {
              _userId = recoveredId;
            });
            // Force refresh all data
            _initPersistentStreams();
          }
        } else {
          debugPrint(
            "[IDENTITY] Local identity verified against phone anchor.",
          );
        }
      }
    } catch (e) {
      debugPrint("[IDENTITY] Recovery error: $e");
    }
  }

  Future<void> _fetchRadarBarbers() async {
    if (_userLat == null || _userLng == null) return;
    try {
      final barbers = await _barberService.getRadarBarbers(
        _userLat!,
        _userLng!,
      );
      setState(() => _radarBarbers = barbers);
    } catch (e) {
      debugPrint("Error fetching radar barbers: $e");
    }
  }

  void _initPersistentStreams() {
    _inspirationStream =
        BaasClient.collection('users')
            .where('userType', isEqualTo: 'barber')
            .where('verificationStatus', isEqualTo: 'approved')
            .where('isDiscoverable', isEqualTo: true)
            .limit(50)
            .snapshots();

    _appointmentSubscription?.cancel();
    _appointmentSubscription = null;
    _upcomingBookingStream = null;
    _nudgeInsightsFuture = null;

    if (_userId != null && _userId!.isNotEmpty) {
      _upcomingBookingStream =
          BaasClient.collection(
            'appointments',
          ).where('customerId', isEqualTo: _userId).snapshots();

      // Listen to appointments to identify visited barbers
      _appointmentSubscription = BaasClient.collection('appointments')
          .where('customerId', isEqualTo: _userId)
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                final Set<String> barberIds = {};
                for (var doc in snapshot.docs) {
                  final d = doc.data();
                  if (d['barberId'] != null) barberIds.add(d['barberId']);
                }
                setState(() {
                  _visitedBarberIds = barberIds.toList();
                });
                debugPrint(
                  "[DIAGNOSTIC] Appts Stream -> Found ${barberIds.length} unique barbers: $_visitedBarberIds",
                );
                if (_visitedBarberIds.isNotEmpty) {
                  debugPrint(
                    "[DIAGNOSTIC] Service history confirmed. Hiding area warnings.",
                  );
                }
              }
            },
            onError: (err) {
              debugPrint("[DIAGNOSTIC] Appts Stream ERROR: $err");
            },
          );

      _nudgeInsightsFuture = HeuristicService.getGroomingInsights(_userId!);
    }
  }

  Future<void> _requestLocationAndDetect() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        _saveLocation(
          place.locality ?? "Vadodara",
          place.postalCode ?? "390001",
          position.latitude,
          position.longitude,
        );
      }
    } catch (e) {
      _saveLocation("Vadodara", "390001", 22.3072, 73.1812);
    }
  }

  Future<void> _saveLocation(
    String city,
    String pincode,
    double? lat,
    double? lng,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userCity', city);
    await prefs.setString('userPincode', pincode);
    await prefs.setDouble('lat', lat ?? 0.0);
    await prefs.setDouble('lng', lng ?? 0.0);
    setState(() {
      _currentCity = city;
      _currentPincode = pincode;
      _userLat = lat;
      _userLng = lng;
    });
    _initPersistentStreams();
    _fetchRadarBarbers();
  }

  @override
  void dispose() {
    _appointmentSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          '${_getGreetingText()}, $_userName',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
            ),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerBookingsScreen(),
                  ),
                ),
          ),
          GestureDetector(
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerProfileSettings(),
                ),
              );
              if (updated == true) _loadLocation();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              child: CircleAvatar(
                backgroundColor: Colors.white12,
                child: ClipOval(
                  child: Image.network(
                    'https://ui-avatars.com/api/?name=$_userName&background=00D189&color=fff',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 10),
                GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CitySearchScreen(),
                        ),
                      ).then((res) {
                        if (res != null) {
                          _saveLocation(
                            res['city'],
                            res['pincode'],
                            res['lat'],
                            res['lng'],
                          );
                        }
                      }),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF00D189),
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "$_currentCity - $_currentPincode",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSearchBar(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildIntelligenceNudges(),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadLocation();
                if (mounted) setState(() {});
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: _buildVadodaraOnlyBanner(),
                  ),

                  // Isolated AI Style Match Card
                  _buildProfileStatusNudge(),

                  // Independent My Barber Section
                  _buildMyBarberSection(),

                  const SizedBox(height: 16),
                  _buildTopBarbersSection(),

                  // Consolidated My Barber Section is now inside the StreamBuilder above.
                  // Removing this redundant block to avoid confusion.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Premium Style Studio'),
                        TextButton(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AiStylerScreen(),
                                ),
                              ),
                          child: const Text(
                            'Try On',
                            style: TextStyle(color: Color(0xFF00D189)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStyleLookbook(),
                  const SizedBox(height: 16),
                  _buildInspirationFeed(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: _buildSectionTitle('Discover Barbers'),
                  ),
                  const SizedBox(height: 8),
                  _buildDiscoverBarbers(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerBookingsScreen()),
            );
          } else if (index == 2)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiStylerScreen()),
            );
          else if (index == 3)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerProfileSettings(),
              ),
            );
        },
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFF00D189),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'AI Stylist',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: TextField(
            controller: _searchController,
            readOnly: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllBarbersPage()),
              );
            },
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText:
                  _favoriteBarberIds.isEmpty
                      ? "Find your barber on Kesh-Kart..."
                      : 'Search barbers, services, or styles',
              hintStyle: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF00D189),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Color(0xFF00D189)),
                onPressed: () {
                  final val = _searchController.text;
                  if (val.trim().isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllBarbersPage(initialQuery: val),
                      ),
                    );
                  }
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyleMatchCTA() {
    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D189), Color(0xFF00A86B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D189).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.auto_awesome,
                size: 120,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            // Close Button
            Positioned(
              top: 5,
              right: 5,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_ai_card_dismissed', true);
                  setState(() => _isAiCardDismissed = true);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StyleMatchScreen(),
                      ),
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'AI POWERED',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover Your Perfect Style',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Take our visual style match questionnaire',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 19,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildVadodaraOnlyBanner() {
    // Hide if area is Vadodara OR if service is already available (appointments/barbers exist)
    if (_currentCity.toLowerCase() == 'vadodara' ||
        _visitedBarberIds.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00D189).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D189).withOpacity(0.3)),
      ),
      child: Text(
        "Service area: live in Vadodara currently",
        style: TextStyle(color: Color(0xFF00D189), fontSize: 12),
      ),
    );
  }

  Widget _buildIntelligenceNudges() {
    if (_nudgeInsightsFuture == null || _nudgeDismissed) {
      return const SizedBox();
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _nudgeInsightsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !(snapshot.data!['hasHistory'] ?? false)) {
          return const SizedBox();
        }
        final insights = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(1),
          height: 36,
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.bolt, color: Colors.orangeAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: _MarqueeWidget(
                  text:
                      "Ready for your next haircut? Your usual gap is ${insights['avgGapDays']} days.",
                  style: GoogleFonts.poppins(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.orangeAccent,
                ),
                onPressed: () => setState(() => _nudgeDismissed = true),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStyleLookbook() {
    return FutureBuilder<List<Hairstyle>>(
      future: HairstyleRepository().getAllStyles(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final style = snapshot.data![index];
              return HairstyleCard(
                hairstyle: style,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => HairstyleDetailsScreen(hairstyle: style),
                      ),
                    ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInspirationFeed() {
    if (_inspirationStream == null) return const SizedBox();
    return StreamBuilder(
      stream: _inspirationStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = (snapshot.data as dynamic).docs;
        return SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.network(
                          data['shopPhotos']?[0] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.store),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        data['shopName'] ?? 'Shop',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  DateTime _parseTime(dynamic rawTime) {
    if (rawTime is DateTime) return rawTime;
    if (rawTime is String) return DateTime.tryParse(rawTime) ?? DateTime.now();
    return DateTime.now();
  }

  Widget _buildFavoriteBarbers(List<String> ids) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        itemCount: ids.length,
        itemBuilder: (context, index) {
          final barberId = ids[index];
          return FutureBuilder(
            future: BaasClient.collection('users').doc(barberId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !(snapshot.data as dynamic).exists) {
                return const SizedBox.shrink();
              }
              final data =
                  (snapshot.data as dynamic).data() as Map<String, dynamic>;
              final img =
                  (data['shopPhotos'] != null &&
                          (data['shopPhotos'] as List).isNotEmpty)
                      ? data['shopPhotos'][0]
                      : null;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => BarberProfileScreen(
                            barberId: barberId,
                            barberData: data,
                          ),
                    ),
                  );
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00D189),
                            width: 2,
                          ),
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
                                  Icons.person,
                                  color: Colors.white54,
                                )
                                : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['shopName'] ?? 'Barber',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileStatusNudge() {
    if (_userId == null) return const SizedBox.shrink();

    final data = _lastSeenProfile;
    final face = data?['faceShape'];

    // Check history (Nuclear Option 1)
    final bool hasHistory =
        _historyInsights.isNotEmpty ||
        _visitedBarberIds.isNotEmpty ||
        _favoriteBarberIds.isNotEmpty;

    // Check face (Nuclear Option 2)
    if (hasHistory || isFilled(face) || _isAiCardDismissed) {
      return const SizedBox.shrink();
    }

    if (data == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: _buildStyleMatchCTA(),
      );
    }

    final bool styleMatchComplete = data['styleMatchCompleted'] == true;
    final bool explicitProfileComplete = data['profileCompleted'] == true;
    final hair = data['hairType'];
    final skin = data['skinType'];
    final style = data['preferredStyle'];

    final bool fieldProfileComplete =
        isFilled(face) && isFilled(hair) && isFilled(skin) && isFilled(style);

    final bool isProfileComplete =
        explicitProfileComplete || styleMatchComplete || fieldProfileComplete;

    if (isProfileComplete) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: _buildStyleMatchCTA(),
    );
  }

  bool isFilled(dynamic val) {
    if (val == null) return false;
    String s = val.toString().trim().toLowerCase();
    return s.isNotEmpty &&
        s != 'not set' &&
        s != 'unset' &&
        s != 'unknown' &&
        s != 'guest';
  }

  Widget _buildMyBarberSection() {
    if (_userId == null) return const SizedBox.shrink();

    return StreamBuilder<BaasQuerySnapshot>(
      stream: _upcomingBookingStream,
      builder: (context, upcomingSnapshot) {
        final List<BaasSnapshot> upcomingDocs =
            upcomingSnapshot.hasData ? upcomingSnapshot.data!.docs : [];

        if (!_historyLoaded && _historyInsights.isEmpty) {
          return const SizedBox.shrink();
        }

        final fullInsights = _historyInsights;

        if (fullInsights.isEmpty) {
          if (_favoriteBarberIds.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: _buildSectionTitle('Your Barbers'),
                ),
                const SizedBox(height: 12),
                _buildFavoriteBarbers(_favoriteBarberIds),
                const SizedBox(height: 16),
              ],
            );
          }
          return const SizedBox.shrink();
        }

        // Limit to 4 latest barbers as requested
        final insights = fullInsights.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Your Barbers'),
                  TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllBarbersPage(),
                          ),
                        ),
                    child: const Text(
                      'See All',
                      style: TextStyle(color: Color(0xFF00D189)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                itemCount: insights.length,
                itemBuilder: (context, index) {
                  final insight = insights[index];
                  final barberId = insight['barberId'];

                  // Safely find if there is an upcoming booking for THIS barber
                  final matching =
                      upcomingDocs
                          .where((doc) => (doc.data()?['barberId']) == barberId)
                          .toList();

                  final BaasSnapshot? upcoming =
                      matching.isNotEmpty ? matching.first : null;

                  return _buildMyBarberCard(
                    insight,
                    upcomingAppointment: upcoming?.data(),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildMyBarberCard(
    Map<String, dynamic> insight, {
    Map<String, dynamic>? upcomingAppointment,
  }) {
    final barberId = insight['barberId'];
    final barberName = insight['barberName'] ?? "KeshKart Style";
    final lastVisit =
        insight['lastVisit'] is DateTime
            ? insight['lastVisit'] as DateTime
            : DateTime.now();
    final avgGap = (insight['avgGapDays'] as num?)?.toInt() ?? 15;

    final daysAgo = DateTime.now().difference(lastVisit).inDays;
    final screenWidth = MediaQuery.of(context).size.width;

    DateTime? nextTime;
    if (upcomingAppointment != null) {
      nextTime = _parseTime(upcomingAppointment['time']);
    }

    return Container(
      width: screenWidth - 22,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage(
            "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=2070&auto=format&fit=crop",
          ),
          fit: BoxFit.cover,
          opacity: 0.65, // Increased clarity
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.2), // Reduced overlay
            Colors.black.withOpacity(0.85),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 4,
            sigmaY: 4,
          ), // Reduced blur from 12
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D189).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "LATEST VISIT",
                        style: TextStyle(
                          color: Color(0xFF00D189),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (nextTime != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "NEXT: ${TimeOfDay.fromDateTime(nextTime).format(context)}",
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Your Barber",
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
                Text(
                  barberName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Last Visit",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            "-$daysAgo days ago",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Avg Gap",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            "$avgGap days",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => BarberProfileScreen(
                                      barberId: barberId,
                                      barberData: {'name': barberName},
                                    ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D189),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Book Again",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AllBarbersPage(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white24,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "View Slots",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarbersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumBarberCarousel(
          barbers: _radarBarbers,
          onBarberTap: (barber) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => BarberProfileScreen(
                      barberId: barber.barberId,
                      barberData: {
                        'name': barber.name,
                        'rating': barber.rating,
                        'shopPhotos': [barber.profileImage],
                      },
                    ),
              ),
            );
          },
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllBarbersPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDiscoverBarbers() {
    if (_inspirationStream == null) return const SizedBox();
    return StreamBuilder<BaasQuerySnapshot>(
      stream: _inspirationStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Could not load barbers: ${snapshot.error}",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D189)),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = Map<String, dynamic>.from(docs[index].data() ?? {});
            final barberId = docs[index].id;
            final photos = List<String>.from(data['shopPhotos'] ?? []);
            final img = photos.isNotEmpty ? photos.first : null;

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => BarberProfileScreen(
                          barberId: barberId,
                          barberData: data,
                        ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(11, 0, 11, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          img != null
                              ? Image.network(
                                img,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                width: 80,
                                height: 80,
                                color: Colors.white10,
                                child: const Icon(
                                  Icons.store,
                                  color: Colors.white24,
                                ),
                              ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['shopName'] ?? data['name'] ?? 'Shop',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${data['rating'] ?? '4.8'}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFF00D189),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data['pincode']?.toString() ?? 'Nearby',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D189).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Open Now",
                              style: TextStyle(
                                color: Color(0xFF00D189),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white24,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeWidget({required this.text, required this.style});

  @override
  State<_MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<_MarqueeWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() async {
    while (_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!_scrollController.hasClients) return;

      final double maxScrollExtent = _scrollController.position.maxScrollExtent;
      final double pixelsPerSecond = 50.0;
      final int durationInSeconds = (maxScrollExtent / pixelsPerSecond).ceil();

      if (maxScrollExtent > 0) {
        await _scrollController.animateTo(
          maxScrollExtent,
          duration: Duration(seconds: durationInSeconds),
          curve: Curves.linear,
        );
        if (!_scrollController.hasClients) return;
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(0.0);
      } else {
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}
