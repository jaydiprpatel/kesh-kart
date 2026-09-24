import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bedrock_client.dart';
import 'customer_profile_page.dart';
import 'customer_bookings_page.dart';
import 'service_selection_screen.dart';
import 'discovery_view.dart';
import '../services/realtime_service.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final KeshKartRealtimeService _realtime = KeshKartRealtimeService();
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  final Set<String> _subscribedBarberIds = <String>{};
  bool _loading = true;
  String? _error, _userId;
  String _name = '', _location = 'Use my location';
  double? _lat, _lng;
  List<Map<String, dynamic>> _barbers = [], _appointments = [];
  @override
  void initState() {
    super.initState();
    _startRealtime();
    _load();
  }

  Future<void> _startRealtime() async {
    _realtimeSub = _realtime.events.listen(_handleRealtimeEvent);
    await _realtime.connect();
    if (mounted) _subscribeToBarbers();
  }

  void _subscribeToBarbers({bool force = false}) {
    if (!_realtime.isConnected) return;
    for (final barber in _barbers) {
      final id =
          '${barber['id'] ?? barber['_id'] ?? barber['uid'] ?? ''}'.trim();
      if (id.isEmpty || (!force && !_subscribedBarberIds.add(id))) continue;
      _subscribedBarberIds.add(id);
      _realtime.subscribeDocument(id);
    }
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    if (type == 'socket_reconnected') {
      _subscribeToBarbers(force: true);
      return;
    }
    if (type != 'document_change') return;

    final rawPayload = event['payload'];
    final payload =
        rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : <String, dynamic>{};
    final rawDocument = payload['document'];
    final document =
        rawDocument is Map
            ? Map<String, dynamic>.from(rawDocument)
            : <String, dynamic>{};
    final collection =
        '${document['collection'] ?? payload['collection'] ?? ''}';
    if (collection != 'users') return;

    final documentId =
        '${document['id'] ?? payload['document_id'] ?? payload['id'] ?? ''}';
    final rawData = document['data'] ?? payload['data'];
    final delta =
        rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{};
    if (documentId.isEmpty ||
        (!delta.containsKey('isOpen') && !delta.containsKey('isActive'))) {
      return;
    }
    final index = _barbers.indexWhere(
      (barber) =>
          '${barber['id'] ?? barber['_id'] ?? barber['uid'] ?? ''}' ==
          documentId,
    );
    if (index < 0 || !mounted) return;

    final updated = List<Map<String, dynamic>>.from(_barbers);
    updated[index] = {...updated[index], ...delta};
    setState(() => _barbers = updated);
  }

  Map<String, dynamic> _unwrap(dynamic row) {
    if (row is! Map) return {};
    return {
      ...Map<String, dynamic>.from(row['data'] is Map ? row['data'] : row),
      if (row['id'] != null) 'id': row['id'],
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('bedrock_user_id') ?? prefs.getString('userId');
      _name = prefs.getString('name') ?? '';
      _lat = prefs.getDouble('lat');
      _lng = prefs.getDouble('lng');
      _location = prefs.getString('locationLabel') ?? 'Use my location';
      if (_userId == null || _userId!.isEmpty) {
        throw StateError('Please sign in again.');
      }
      final results = await Future.wait([
        BedrockClient().queryCollection(
          'users',
          params: {'userType': 'barber'},
          throwOnError: true,
        ),
        BedrockClient().queryCollection(
          'appointments',
          params: {'customerId': _userId!},
          throwOnError: true,
        ),
      ]);
      final barbers =
          results[0]
              .map(_unwrap)
              .where((b) => b['profileCompleted'] == true)
              .toList();
      for (final barber in barbers) {
        final location = barber['location'];
        final lat =
            location is Map ? double.tryParse('${location['lat']}') : null;
        final lng =
            location is Map ? double.tryParse('${location['lng']}') : null;
        if (_lat != null && _lng != null && lat != null && lng != null) {
          final a =
              math.pow(math.sin((lat - _lat!) * math.pi / 360), 2) +
              math.cos(_lat! * math.pi / 180) *
                  math.cos(lat * math.pi / 180) *
                  math.pow(math.sin((lng - _lng!) * math.pi / 360), 2);
          barber['distanceKm'] = 12742 * math.asin(math.sqrt(a.clamp(0, 1)));
        }
      }
      barbers.sort(
        (a, b) => ((a['distanceKm'] as num?) ?? double.infinity).compareTo(
          (b['distanceKm'] as num?) ?? double.infinity,
        ),
      );
      if (!mounted) return;
      setState(() {
        _barbers = barbers;
        _appointments = results[1].map(_unwrap).toList();
        _loading = false;
      });
      await Future.wait(barbers.map(_resolveDisplayShopPhoto));
      if (!mounted) return;
      setState(() => _barbers = List<Map<String, dynamic>>.from(barbers));
      _subscribeToBarbers();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'We could not load your barbers and appointments. Please try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _resolveDisplayShopPhoto(Map<String, dynamic> barber) async {
    final barberId =
        '${barber['id'] ?? barber['_id'] ?? barber['uid'] ?? ''}'.trim();
    if (barberId.isNotEmpty &&
        ('${barber['verifiedShopPhotoUrl'] ?? barber['shopVerificationPhotoUrl'] ?? ''}'
            .trim()
            .isNotEmpty)) {
      final approvedUrl = await BedrockClient().getApprovedShopPhotoUrl(
        barberId,
      );
      if (approvedUrl != null && approvedUrl.isNotEmpty) {
        barber['displayShopPhotoUrl'] = approvedUrl;
        return;
      }
    }
    for (final candidate in _photoCandidates(barber)) {
      final value = _photoValue(candidate);
      if (value.isEmpty) continue;
      try {
        final signedUrl = await BedrockClient().getDownloadUrl(value);
        if (signedUrl != null && signedUrl.isNotEmpty) {
          barber['displayShopPhotoUrl'] = signedUrl;
          return;
        }
      } catch (_) {
        // A missing gallery image must not prevent discovery from loading.
      }
    }
  }

  Iterable<dynamic> _photoCandidates(Map<String, dynamic> barber) sync* {
    final gallery = barber['shopPhotos'];
    if (gallery is List) {
      yield* gallery;
    } else if (gallery != null) {
      yield gallery;
    }
    yield barber['verifiedShopPhotoUrl'];
    yield barber['shopVerificationPhotoUrl'];
    yield barber['profileUrl'];
  }

  String _photoValue(dynamic candidate) {
    if (candidate is Map) {
      candidate =
          candidate['url'] ??
          candidate['downloadUrl'] ??
          candidate['download_url'] ??
          candidate['path'] ??
          candidate['storagePath'];
    }
    return candidate?.toString().trim() ?? '';
  }

  Future<void> _useLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location services, then try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Allow location access to sort barbers by distance.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final location = {
        'lat': position.latitude,
        'lng': position.longitude,
        'label': 'Near your saved location',
      };
      if (_userId == null ||
          await BedrockClient().updateDocument('users', _userId!, {
                'location': location,
              }) ==
              null) {
        throw StateError('Location could not be saved. Please retry.');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('lat', position.latitude);
      await prefs.setDouble('lng', position.longitude);
      await prefs.setString('locationLabel', 'Near your saved location');
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Location unavailable. You can still search by shop or area.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _realtime.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomerDiscoveryView(
    name: _name,
    location: _location,
    loading: _loading,
    error: _error,
    barbers: _barbers,
    appointments: _appointments,
    onRefresh: _load,
    onLocation: _useLocation,
    onHistory: () => _open(const CustomerBookingsPage()),
    onProfile: () => _open(const CustomerProfilePage()),
    onBook: (barber) => _open(ServiceSelectionScreen(barber: barber)),
    onPrivacy:
        kIsWeb ? () => Navigator.of(context).pushNamed('/privacy') : null,
    onTerms: kIsWeb ? () => Navigator.of(context).pushNamed('/terms') : null,
  );
}
