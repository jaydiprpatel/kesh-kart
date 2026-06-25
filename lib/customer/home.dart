import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/customer_smart_stylist_page.dart';
import 'package:kesh_kart/customer/customer_barber_list_page.dart';
import 'package:kesh_kart/customer/customer_bookings_page.dart';
import 'package:kesh_kart/customer/customer_profile_page.dart';
import 'package:kesh_kart/customer/check_in_status_screen.dart';
import 'package:kesh_kart/customer/select_slot.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  static const Color _green = Color(0xFF00D084);

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _name = 'User';
  String _phone = '';
  String _email = '';
  String _locationLabel = 'Add your location';
  String? _userId;
  double? _lat;
  double? _lng;
  List<Map<String, dynamic>> _barbers = [];
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadHome();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('bedrock_user_id') ?? prefs.getString('userId');
    _name = prefs.getString('name') ?? prefs.getString('barberName') ?? 'User';
    _phone = prefs.getString('phone') ?? '';
    _email = prefs.getString('email') ?? '';
    _lat = prefs.getDouble('lat');
    _lng = prefs.getDouble('lng');
    _locationLabel = prefs.getString('locationLabel') ?? _locationLabel;

    if (_userId != null && _userId!.isNotEmpty) {
      final profile = await BedrockClient().getDocument('users', _userId!);
      final data = _unwrapData(profile);
      if (data.isNotEmpty) {
        _name = _string(data['name'], fallback: _name);
        _phone = _string(data['phone'], fallback: _phone);
        _email = _string(data['email'], fallback: _email);
        final location = data['location'];
        if (location is Map) {
          _lat = _toDouble(location['lat']) ?? _lat;
          _lng = _toDouble(location['lng']) ?? _lng;
          _locationLabel = _locationText(location);
        }
        await prefs.setString('name', _name);
        await prefs.setString('barberName', _name);
        await prefs.setString('phone', _phone);
        await prefs.setString('email', _email);
        await prefs.setString('locationLabel', _locationLabel);
        if (_lat != null && _lng != null) {
          await prefs.setDouble('lat', _lat!);
          await prefs.setDouble('lng', _lng!);
        }
      }
    }

    final rows = await BedrockClient().queryCollection(
      'users',
      params: {'userType': 'barber'},
    );
    final barbers =
        rows
            .map(_unwrapData)
            .where((data) => data.isNotEmpty)
            .where((data) => data['profileCompleted'] == true)
            .toList();

    final appointmentRows =
        _userId == null || _userId!.isEmpty
            ? <dynamic>[]
            : await BedrockClient().queryCollection(
              'appointments',
              params: {'customerId': _userId!},
            );
    final List<Map<String, dynamic>> appointments =
        appointmentRows
            .map((e) => _unwrapData(e))
            .where((data) => data.isNotEmpty)
            .toList()
            .cast<Map<String, dynamic>>()
          ..sort(
            (a, b) =>
                _millis(a['slotStart']).compareTo(_millis(b['slotStart'])),
          );

    barbers.sort((a, b) {
      final aDistance = _distanceKm(a);
      final bDistance = _distanceKm(b);
      if (aDistance == null && bDistance == null) return 0;
      if (aDistance == null) return 1;
      if (bDistance == null) return -1;
      return aDistance.compareTo(bDistance);
    });

    if (!mounted) return;
    setState(() {
      _barbers = barbers;
      _appointments = appointments;
      _isLoading = false;
    });
  }

  Future<void> _pickAndSaveLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required.')),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final location = {
        'lat': position.latitude,
        'lng': position.longitude,
        'label':
            _locationLabel == 'Add your location'
                ? 'Location saved'
                : _locationLabel,
      };
      final userId = _userId;

      if (userId != null && userId.isNotEmpty) {
        await BedrockClient().updateDocument('users', userId, {
          'location': location,
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('lat', position.latitude);
      await prefs.setDouble('lng', position.longitude);
      await prefs.setString('locationLabel', _locationText(location));

      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationLabel = _locationText(location);
      });
      await _loadHome();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save location: $e')));
    }
  }

  List<Map<String, dynamic>> get _visibleBarbers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _barbers;

    return _barbers.where((barber) {
      final services = _services(barber).map((s) => s.toLowerCase()).join(' ');
      final haystack =
          [
            barber['shopName'],
            barber['name'],
            barber['shopAddress'],
            barber['email'],
            barber['phone'],
            services,
          ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return initials.isEmpty ? 'US' : initials;
  }

  Map<String, dynamic>? get _nextAppointment {
    final now = DateTime.now().millisecondsSinceEpoch;
    final upcoming =
        _appointments.where((doc) => _millis(doc['slotStart']) >= now).where((
          doc,
        ) {
          final status = _string(doc['status']).toLowerCase();
          return status.isEmpty ||
              ['booked', 'arrived', 'in_progress'].contains(status);
        }).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort(
      (a, b) => _millis(a['slotStart']).compareTo(_millis(b['slotStart'])),
    );
    return upcoming.first;
  }

  _RecentBarberInfo? get _recentBarberInfo {
    final datedAppointments =
        _appointments
            .where((appointment) => _millis(appointment['slotStart']) > 0)
            .toList()
          ..sort(
            (a, b) =>
                _millis(b['slotStart']).compareTo(_millis(a['slotStart'])),
          );
    if (datedAppointments.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final pastAppointments =
        datedAppointments
            .where((appointment) => _millis(appointment['slotStart']) <= now)
            .toList();
    final appointment =
        pastAppointments.isNotEmpty
            ? pastAppointments.first
            : datedAppointments.first;
    final appointmentBarberId = _appointmentBarberId(appointment);

    Map<String, dynamic>? barber;
    if (appointmentBarberId.isNotEmpty) {
      for (final candidate in _barbers) {
        if (_barberId(candidate) == appointmentBarberId) {
          barber = candidate;
          break;
        }
      }
    }

    barber ??= _barberFromAppointment(appointment);
    final shopName = _string(
      barber['shopName'],
      fallback: _string(
        appointment['shopName'],
        fallback: _string(barber['name'], fallback: 'Your barber'),
      ),
    );

    return _RecentBarberInfo(
      barber: barber,
      shopName: shopName,
      lastVisit: _relativeVisitLabel(_millis(appointment['slotStart'])),
      avgGap: _averageGapLabel(appointmentBarberId),
      photo: _firstPhoto(barber),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerProfilePage()),
    );
  }

  void _openBookings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerBookingsPage()),
    );
  }

  void _openSmartStylist() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerSmartStylistPage()),
    );
  }

  void _openBarberList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerBarberListPage(barbers: _visibleBarbers),
      ),
    );
  }

  void _openBooking(Map<String, dynamic> barber) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SelectSlotScreen(barber: barber)),
    );
  }

  void _openCheckIn(Map<String, dynamic> appointment) {
    final shopId = _appointmentBarberId(appointment);
    if (shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop details are not available yet.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckInStatusScreen(shopId: shopId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                    onRefresh: _loadHome,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        _buildUpcomingCard(),
                        _buildYourBarbersSection(),
                        _buildSmartStylistBanner(),
                        const SizedBox(height: 24),
                        _buildSmartRecommendations(),
                        const SizedBox(height: 24),
                        _buildBarberRadar(),
                      ],
                    ),
                  ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openSmartStylist,
          backgroundColor: const Color(0xFF091426),
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: _openProfile,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF091426),
              child: Text(
                _initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: const TextStyle(
                    color: Color(0xFF54647A),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _name,
                  style: const TextStyle(
                    color: Color(0xFF091426),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _pickAndSaveLocation,
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF191C1D),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _lat == null || _lng == null
                      ? 'Add location'
                      : _locationLabel,
                  style: const TextStyle(
                    color: Color(0xFF191C1D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF191C1D),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _openBarberList(),
        decoration: InputDecoration(
          hintText: 'Search barber, service, or area',
          hintStyle: const TextStyle(color: Color(0xFF8A94A3), fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF091426)),
          suffixIcon:
              _searchController.text.isEmpty
                  ? null
                  : IconButton(
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close, color: Color(0xFF54647A)),
                  ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildUpcomingCard() {
    final next = _nextAppointment;
    if (next == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            _roundIcon(Icons.calendar_today_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No upcoming booking',
                    style: TextStyle(
                      color: Color(0xFF091426),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Book your next slot from Barber Radar.',
                    style: TextStyle(color: Color(0xFF54647A), fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: _openBarberList, child: const Text('Book')),
          ],
        ),
      );
    }

    final millis = _millis(next['slotStart']);
    final date =
        millis == 0 ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    final isToday =
        date != null &&
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    final status = _string(next['status'], fallback: 'booked');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _roundIcon(Icons.event_available_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _string(next['shopName'], fallback: 'Upcoming booking'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF091426),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${date == null ? 'Date pending' : DateFormat('EEE, d MMM').format(date)} - ${_timeLabel(next['slotStart'])} - ${_titleCase(status)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF54647A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: isToday ? () => _openCheckIn(next) : _openBookings,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF091426),
              side: const BorderSide(color: Color(0xFF091426)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isToday ? 'Check in' : 'View'),
          ),
        ],
      ),
    );
  }

  Widget _buildYourBarbersSection() {
    final info = _recentBarberInfo;
    if (info == null) return const SizedBox(height: 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Your Barbers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF091426),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildYourBarberCard(info),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD1D1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFE23A3A)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filling Fast',
                      style: TextStyle(
                        color: Color(0xFFE23A3A),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Weekend slots for ${info.shopName} are booking up.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF54647A),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildYourBarberCard(_RecentBarberInfo info) {
    final image = info.photo;
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image == null)
            Image.asset('assets/images/barber.png', fit: BoxFit.cover)
          else
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Image.asset(
                    'assets/images/barber.png',
                    fit: BoxFit.cover,
                  ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'LATEST VISIT',
                    style: TextStyle(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Your Barber',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildVisitMetric('Last visit', info.lastVisit),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: _buildVisitMetric('Avg gap', info.avgGap)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => _openBooking(info.barber),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: const Color(0xFF091426),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Book Again',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => _openBooking(info.barber),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.34),
                            ),
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.22,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('View Slots'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSmartStylistBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Smart Stylist is Ready',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF091426),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Discover your perfect look with smart style guidance. Tap to start your personalized style journey.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF45474C),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openSmartStylist,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF091426),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: const Icon(Icons.filter_center_focus, size: 18),
            label: const Text(
              'SCAN FACE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Smart Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF091426),
                ),
              ),
              TextButton(
                onPressed: _openSmartStylist,
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF54647A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildRecommendationCard(
                'Best for Your Face',
                'Smart Recommended Styles',
                'assets/images/barber.png',
                Icons.auto_awesome,
              ),
              const SizedBox(width: 12),
              _buildRecommendationCard(
                'Trending',
                'In Khambhat',
                null,
                Icons.trending_up,
                isPlaceholder: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    String title,
    String subtitle,
    String? imagePath,
    IconData icon, {
    bool isPlaceholder = false,
  }) {
    return InkWell(
      onTap: _openSmartStylist,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E3E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0E1FB),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  image:
                      imagePath != null
                          ? DecorationImage(
                            image: AssetImage(imagePath),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    isPlaceholder
                        ? Center(
                          child: Icon(
                            icon,
                            size: 40,
                            color: const Color(0xFF54647A),
                          ),
                        )
                        : Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(
                                0xFF091426,
                              ).withValues(alpha: 0.8),
                              child: Icon(icon, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF091426),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF45474C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarberRadar() {
    final barbers = _visibleBarbers;
    final previewBarbers = barbers.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: Color(0xFF091426),
              ),
              const SizedBox(width: 8),
              const Text(
                'Barber Radar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF091426),
                ),
              ),
              const Spacer(),
              if (barbers.isNotEmpty)
                TextButton(
                  onPressed: _openBarberList,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00C47A),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View all',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (barbers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No barbers found nearby.'),
          )
        else
          ...previewBarbers.map((barber) => _buildBarberListItem(barber)),
        if (barbers.length > previewBarbers.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _openBarberList,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF091426),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'View all ${barbers.length} barbers',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBarberListItem(Map<String, dynamic> barber) {
    final shopName = _string(
      barber['shopName'],
      fallback: _string(barber['name'], fallback: 'Barber Shop'),
    );
    final distance = _distanceKm(barber);
    final photo = _firstPhoto(barber);
    final ratingLabel = _ratingLabel(barber);
    final services = _services(barber);
    final availability = _availabilityLabel(barber);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo == null)
                  Image.asset('assets/images/barber.png', fit: BoxFit.cover)
                else
                  Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Image.asset(
                          'assets/images/barber.png',
                          fit: BoxFit.cover,
                        ),
                  ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      availability.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF091426),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF091426),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_outline,
                          size: 16,
                          color: Color(0xFFFFB347),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ratingLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF091426),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_distanceLabel(distance)} • ${barber['shopAddress'] ?? 'Main Street'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF45474C),
                  ),
                ),
                const SizedBox(height: 12),
                if (services.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        services
                            .take(3)
                            .map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF45474C),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _openBooking(barber),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF091426),
                      side: const BorderSide(color: Color(0xFF091426)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Book Appointment',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E3E4))),
      ),
      padding: const EdgeInsets.only(bottom: 20, top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_filled, label: 'Home', active: true),
          _NavItem(
            icon: Icons.calendar_month_outlined,
            label: 'Bookings',
            onTap: _openBookings,
          ),
          _NavItem(
            icon: Icons.auto_awesome_outlined,
            label: 'Smart Stylist',
            onTap: _openSmartStylist,
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            onTap: _openProfile,
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E3E4)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _roundIcon(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: const Color(0xFF091426), size: 21),
    );
  }

  String _titleCase(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    return text
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  Map<String, dynamic> _unwrapData(dynamic row) {
    if (row is! Map) return {};
    final data = row['data'];
    if (data is Map) {
      return {
        ...Map<String, dynamic>.from(data),
        if (row['id'] != null) 'id': row['id'],
        if (row['_id'] != null) '_id': row['_id'],
      };
    }
    return Map<String, dynamic>.from(row);
  }

  List<String> _services(Map<String, dynamic> barber) {
    final services = barber['services'];
    if (services is! List) return [];
    return services
        .map((service) {
          if (service is Map) return _string(service['name']);
          return _string(service);
        })
        .where((service) => service.isNotEmpty)
        .toList();
  }

  String? _firstPhoto(Map<String, dynamic> barber) {
    final photos = barber['shopPhotos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is String && first.isNotEmpty) return first;
    }
    return null;
  }

  Map<String, dynamic> _barberFromAppointment(
    Map<String, dynamic> appointment,
  ) {
    final id = _appointmentBarberId(appointment);
    final shopName = _string(
      appointment['shopName'],
      fallback: _string(appointment['barberName'], fallback: 'Your barber'),
    );
    return {
      'id': id,
      '_id': id,
      'uid': id,
      'shopName': shopName,
      'name': shopName,
    };
  }

  String _barberId(Map<String, dynamic> barber) {
    return _string(
      barber['id'],
      fallback: _string(
        barber['_id'],
        fallback: _string(
          barber['uid'],
          fallback: _string(
            barber['shopId'],
            fallback: _string(barber['barberId']),
          ),
        ),
      ),
    );
  }

  String _appointmentBarberId(Map<String, dynamic> appointment) {
    return _string(
      appointment['shopId'],
      fallback: _string(
        appointment['barberId'],
        fallback: _string(
          appointment['barberUid'],
          fallback: _string(appointment['providerId']),
        ),
      ),
    );
  }

  String _relativeVisitLabel(int millis) {
    if (millis <= 0) return 'Recently';
    final visit = DateTime.fromMillisecondsSinceEpoch(millis);
    final today = DateTime.now();
    final visitDate = DateTime(visit.year, visit.month, visit.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    final days = todayDate.difference(visitDate).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  String _averageGapLabel(String barberId) {
    if (barberId.isEmpty) return 'First visit';
    final visits =
        _appointments
            .where(
              (appointment) => _appointmentBarberId(appointment) == barberId,
            )
            .map((appointment) => _millis(appointment['slotStart']))
            .where((millis) => millis > 0)
            .toList()
          ..sort();

    if (visits.length < 2) return 'First visit';

    var totalDays = 0;
    for (var i = 1; i < visits.length; i++) {
      final previous = DateTime.fromMillisecondsSinceEpoch(visits[i - 1]);
      final current = DateTime.fromMillisecondsSinceEpoch(visits[i]);
      totalDays += current.difference(previous).inDays.abs();
    }
    final average = (totalDays / (visits.length - 1)).round();
    if (average <= 0) return 'Same day';
    return '$average days';
  }

  String _locationText(Map location) {
    final city = _string(
      location['city'],
      fallback: _string(
        location['locality'],
        fallback: _string(location['area']),
      ),
    );
    final pincode = _string(
      location['pincode'],
      fallback: _string(
        location['postalCode'],
        fallback: _string(location['zip']),
      ),
    );
    final joined = [city, pincode].where((part) => part.isNotEmpty).join(' - ');
    if (joined.isNotEmpty) return joined;

    final explicit = _string(
      location['label'],
      fallback: _string(
        location['address'],
        fallback: _string(location['formattedAddress']),
      ),
    );
    if (explicit.isNotEmpty && !_looksLikeCoordinates(explicit)) {
      return explicit;
    }

    final lat = _toDouble(location['lat']);
    final lng = _toDouble(location['lng']);
    if (lat != null && lng != null) {
      return 'Location saved';
    }
    return 'Location saved';
  }

  bool _looksLikeCoordinates(String value) {
    return RegExp(r'^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$').hasMatch(value.trim());
  }

  int _millis(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return DateTime.tryParse(value?.toString() ?? '')?.millisecondsSinceEpoch ??
        0;
  }

  String _timeLabel(dynamic value) {
    final millis = _millis(value);
    if (millis == 0) return 'time pending';
    return DateFormat(
      'h:mm a',
    ).format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  String _ratingLabel(Map<String, dynamic> barber) {
    final rating = _toDouble(
      barber['rating'] ??
          barber['averageRating'] ??
          barber['avgRating'] ??
          barber['reviewRating'],
    );
    if (rating == null || rating <= 0) return 'New';
    return rating.toStringAsFixed(1);
  }

  String _availabilityLabel(Map<String, dynamic> barber) {
    final raw =
        _string(
          barber['availability'],
          fallback: _string(
            barber['status'],
            fallback: _string(barber['shopStatus']),
          ),
        ).toLowerCase();
    if (raw.contains('open') || raw.contains('available')) return 'Available';
    if (raw.contains('closed') || raw.contains('busy')) return 'Busy';
    final active = barber['isOpen'] ?? barber['available'];
    if (active is bool) return active ? 'Available' : 'Busy';
    return '';
  }

  String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? _distanceKm(Map<String, dynamic> barber) {
    if (_lat == null || _lng == null) return null;
    final location = barber['location'];
    if (location is! Map) return null;
    final barberLat = _toDouble(location['lat']);
    final barberLng = _toDouble(location['lng']);
    if (barberLat == null || barberLng == null) return null;
    return _haversineKm(_lat!, _lng!, barberLat, barberLng);
  }

  String _distanceLabel(double? distanceKm) {
    if (distanceKm == null) return 'nearby';
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} meters';
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}

class _RecentBarberInfo {
  final Map<String, dynamic> barber;
  final String shopName;
  final String lastVisit;
  final String avgGap;
  final String? photo;

  const _RecentBarberInfo({
    required this.barber,
    required this.shopName,
    required this.lastVisit,
    required this.avgGap,
    required this.photo,
  });
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF091426) : const Color(0xFF8590A6);
    return InkWell(
      onTap: active ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
