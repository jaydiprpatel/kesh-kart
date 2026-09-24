import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kesh_kart/barber/profile.dart';
import 'package:kesh_kart/barber/queue_management_screen.dart';
import 'package:kesh_kart/barber/service.dart';
import 'package:kesh_kart/barber/barber_receipt_scanner_screen.dart';
import 'package:kesh_kart/barber/barber_subscription_screen.dart';
import 'seats_screen.dart';
import 'insights_screen.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kesh_kart/theme/keshkart_theme.dart';
import 'package:kesh_kart/layout/keshkart_desktop_frame.dart';
import '../services/realtime_service.dart';
import 'dart:async';

class BarberHome extends StatefulWidget {
  const BarberHome({super.key, this.realtime, this.clock});
  final KeshKartRealtimeService? realtime;
  final DateTime Function()? clock;

  @override
  State<BarberHome> createState() => _BarberHomeState();
}

class _ShopApprovalCelebration extends StatelessWidget {
  const _ShopApprovalCelebration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [KeshColors.navySurface, KeshColors.navyPrimary],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: KeshColors.proGold.withValues(alpha: 0.58),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KeshColors.proGold,
                  boxShadow: [
                    BoxShadow(
                      color: KeshColors.proGold.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: KeshColors.navyPrimary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Congratulations!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your shop profile is verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF7E6B9),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You can now turn your shop on and start accepting customer bookings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFDCE5F5),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text("Let's get started"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KeshColors.proGold,
                    foregroundColor: KeshColors.navyPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'I will do this later',
                  style: TextStyle(color: Color(0xFFB9C7DD)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarberHomeState extends State<BarberHome> {
  static const Color _ink = Color(0xFF091426);
  static const Color _muted = Color(0xFF54647A);
  static const Color _green = Color(0xFF00D084);

  late final KeshKartRealtimeService _realtime =
      widget.realtime ?? KeshKartRealtimeService();
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  bool _isLoading = true;
  bool _isOpen = false;
  bool _updatingOpen = false;
  final Set<String> _updatingAppointments = {};
  String _shopId = '';
  String _shopName = 'Barber';
  String _verificationStatus = 'unverified';
  List<String> _shopPhotos = [];
  List<Map<String, dynamic>> _todayAppointments = [];
  List<Map<String, dynamic>> _upcomingAppointments = [];
  Map<String, dynamic>? _subscription;
  bool _approvalCelebrationShowing = false;

  bool get _isVerified => _verificationStatus.toLowerCase() == 'approved';
  bool get _isProActive => _subscription?['is_access_active'] == true;

  String get _proExpiryLabel {
    final raw = _subscription?['next_billing']?.toString();
    final expiry = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    return expiry == null
        ? 'active'
        : 'active until ${DateFormat('d MMM').format(expiry)}';
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _startRealtime();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _realtime.disconnect();
    super.dispose();
  }

  Future<void> _startRealtime() async {
    _realtimeSub = _realtime.events.listen(_handleRealtimeEvent);
    try {
      await _realtime.connect();
      _realtime.ping();
      if (_shopId.isNotEmpty) {
        _realtime.subscribeDocument(_shopId);
      }
    } catch (_) {}
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type'];

    if (type == 'batch') {
      final events = event['events'];
      if (events is List) {
        for (final item in events) {
          if (item is Map<String, dynamic>) {
            _handleRealtimeEvent(item);
          }
        }
      }
      return;
    }

    if (type == 'pong' || type == 'socket_reconnected') {
      if (type == 'socket_reconnected' && _shopId.isNotEmpty) {
        _realtime.subscribeDocument(_shopId);
      }
      return;
    }

    if (type == 'document_change') {
      final docId = (event['document_id'] ?? event['id'])?.toString();
      if (docId != null && docId == _shopId) {
        final delta = event['delta'];
        if (delta is Map<String, dynamic>) {
          List<String>? incomingPhotos;
          if (delta['shopPhotos'] is List) {
            incomingPhotos = _validShopPhotos(
              (delta['shopPhotos'] as List).whereType<String>().toList(),
            );
          }
          final wasApproved = _isVerified;
          String? approvalMarker;
          if (mounted) {
            setState(() {
              if (delta.containsKey('verificationStatus')) {
                _verificationStatus =
                    delta['verificationStatus']?.toString() ?? 'unverified';
                if (_isVerified && !wasApproved) {
                  approvalMarker =
                      delta['shopVerificationReviewedAt']?.toString();
                }
              }
              if (delta.containsKey('isActive')) {
                _isOpen = delta['isActive'] == true || delta['isOpen'] == true;
              } else if (delta.containsKey('isOpen')) {
                _isOpen = delta['isOpen'] == true;
              }
              if (delta.containsKey('shopName')) {
                _shopName = delta['shopName']?.toString() ?? _shopName;
              }
            });
            if (incomingPhotos != null) {
              unawaited(_refreshShopPhotos(incomingPhotos));
            }
            if (approvalMarker != null) {
              unawaited(_maybeCelebrateShopApproval(approvalMarker));
            }
          }
        }
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    Map<String, dynamic>? subscription;
    try {
      subscription = await BedrockClient.instance.getKeshKartSubscription();
    } catch (_) {
      // The dashboard remains usable if the non-critical status chip cannot load.
    }
    final prefs = await SharedPreferences.getInstance();
    _shopId =
        prefs.getString('bedrock_user_id') ?? prefs.getString('userId') ?? '';
    _shopName = prefs.getString('barberName') ?? 'Barber';
    _isOpen = prefs.getBool('isActive') ?? false;
    _shopPhotos = await _resolveShopPhotos(
      _validShopPhotos(prefs.getStringList('shopPhotos') ?? []),
    );
    String? approvalMarker;

    if (_shopId.isNotEmpty) {
      final profile = _unwrapData(
        await BedrockClient().getDocument('users', _shopId),
      );
      if (profile.isNotEmpty) {
        _shopName = _text(
          profile['shopName'],
          fallback: _text(profile['name'], fallback: _shopName),
        );
        _isOpen = profile['isActive'] == true || profile['isOpen'] == true;
        _verificationStatus =
            profile['verificationStatus']?.toString() ?? 'unverified';
        if (_isVerified) {
          approvalMarker = profile['shopVerificationReviewedAt']?.toString();
        }
        if (!_isVerified) {
          _isOpen = false;
          await prefs.setBool('isActive', false);
        }
        final photos = profile['shopPhotos'];
        if (photos is List) {
          _shopPhotos = await _resolveShopPhotos(
            _validShopPhotos(photos.whereType<String>().toList()),
          );
        }
      }
      if (_realtime.isConnected) {
        _realtime.subscribeDocument(_shopId);
      }
      await _loadTodayAppointments(setLoading: false);
    }

    if (!mounted) return;
    setState(() {
      _subscription = subscription;
      _isLoading = false;
    });
    if (_isVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeCelebrateShopApproval(approvalMarker));
      });
    }
  }

  Future<void> _maybeCelebrateShopApproval(String? reviewedAt) async {
    if (!mounted || _approvalCelebrationShowing || _shopId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final marker =
        reviewedAt?.trim().isNotEmpty == true ? reviewedAt!.trim() : 'approved';
    final preferenceKey = 'barber_approval_celebrated_$_shopId';
    if (prefs.getString(preferenceKey) == marker) return;
    await prefs.setString(preferenceKey, marker);

    if (!mounted) return;
    _approvalCelebrationShowing = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Shop approval confirmed',
        barrierColor: KeshColors.navyPrimary.withValues(alpha: 0.62),
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (context, _, __) => const _ShopApprovalCelebration(),
        transitionBuilder: (context, animation, _, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: curve, child: child),
          );
        },
      );
    } finally {
      _approvalCelebrationShowing = false;
    }
  }

  Future<void> _refreshSubscription() async {
    try {
      final subscription =
          await BedrockClient.instance.getKeshKartSubscription();
      if (mounted) setState(() => _subscription = subscription);
    } catch (_) {
      // Keep the previously confirmed status visible during a transient failure.
    }
  }

  Future<void> _loadTodayAppointments({bool setLoading = true}) async {
    if (_shopId.isEmpty) return;
    final rows = await BedrockClient().queryCollection(
      'appointments',
      params: {'shopId': _shopId},
    );
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final appointments =
        rows
            .map(_unwrapData)
            .where((doc) => doc.isNotEmpty)
            .where((doc) => _text(doc['shopId']) == _shopId)
            .toList()
          ..sort(
            (a, b) => _millis(
              a['slotStart'] ?? a['time'],
            ).compareTo(_millis(b['slotStart'] ?? b['time'])),
          );
    final today =
        appointments.where((doc) {
          final slot = _millis(doc['slotStart'] ?? doc['time']);
          return slot >= start && slot < end;
        }).toList();
    final upcoming =
        appointments.where((doc) {
          final slot = _millis(doc['slotStart'] ?? doc['time']);
          return slot >= now.millisecondsSinceEpoch &&
              const {
                'booked',
                'scheduled',
                'confirmed',
                'arrived',
                'in_progress',
              }.contains(_status(doc));
        }).toList();
    if (!mounted) return;
    setState(() {
      _todayAppointments = today;
      _upcomingAppointments = upcoming;
    });
  }

  Future<void> _toggleOpen(bool value) async {
    if (_updatingOpen || _shopId.isEmpty) return;
    if (value && !_isVerified) {
      _showVerificationRequired();
      return;
    }
    setState(() => _updatingOpen = true);
    try {
      final result = await BedrockClient().updateDocument('users', _shopId, {
        'isActive': value,
        'isOpen': value,
      });
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shop status could not be saved. Please retry.'),
            ),
          );
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isActive', value);
      if (mounted) setState(() => _isOpen = value);
    } finally {
      if (mounted) setState(() => _updatingOpen = false);
    }
  }

  void _showVerificationRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Shop can open only after profile verification approval.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: KeshColors.warmIvory,
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) _openInsights();
            if (index == 2) _openInsights(customers: true);
            if (index == 3) _openProfile();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              label: 'My shop',
            ),
          ],
        ),
        body: SafeArea(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : KeshKartDesktopFrame(
                    maxWidth: 1180,
                    child: RefreshIndicator(
                      onRefresh: _loadDashboard,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide =
                              KeshKartDesktopFrame.isWide(context) &&
                              constraints.maxWidth >= 900;
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              wide ? 28 : 16,
                              wide ? 24 : 12,
                              wide ? 28 : 16,
                              28,
                            ),
                            children: [
                              _buildHeader(),
                              _buildStudioPulse(),
                              const SizedBox(height: 20),
                              _buildInsightsEntry(),
                              const SizedBox(height: 20),
                              if (wide)
                                _buildDesktopDashboard()
                              else
                                ..._buildMobileDashboard(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
        ),
      ),
    );
  }

  List<Widget> _buildMobileDashboard() => [
    if (_verificationStatus.toLowerCase() != 'approved') ...[
      _buildVerificationNotice(),
      const SizedBox(height: 16),
    ],
    _buildOpenCard(),
    const SizedBox(height: 16),
    _buildSummaryGrid(),
    const SizedBox(height: 16),
    _buildNextAppointment(),
    const SizedBox(height: 22),
    _sectionTitle('Quick Actions'),
    const SizedBox(height: 12),
    _buildQuickActions(),
    const SizedBox(height: 22),
    _sectionTitle('Today Appointments'),
    const SizedBox(height: 12),
    _buildAppointmentList(),
  ];

  Widget _buildDesktopDashboard() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_verificationStatus.toLowerCase() != 'approved') ...[
                _buildVerificationNotice(),
                const SizedBox(height: 16),
              ],
              _buildOpenCard(),
              const SizedBox(height: 16),
              _buildSummaryGrid(),
              const SizedBox(height: 24),
              _sectionTitle('Quick Actions'),
              const SizedBox(height: 12),
              _buildQuickActions(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNextAppointment(),
              const SizedBox(height: 24),
              _sectionTitle('Today Appointments'),
              const SizedBox(height: 12),
              _buildAppointmentList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudioPulse() {
    final queue =
        _todayAppointments
            .where((doc) => ['arrived', 'in_progress'].contains(_status(doc)))
            .length;
    final completed =
        _todayAppointments
            .where(
              (doc) => ['completed', 'done', 'served'].contains(_status(doc)),
            )
            .length;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KeshColors.navyPrimary, KeshColors.navySurface],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: KeshColors.navyPrimary.withValues(alpha: 0.20),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (_isOpen
                          ? KeshColors.emeraldSuccess
                          : KeshColors.textMuted)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _isOpen
                                ? KeshColors.emeraldSuccess
                                : KeshColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _isOpen ? 'SHOP OPEN' : 'SHOP CLOSED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.insights_rounded,
                color: KeshColors.proGold.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat(
              'EEEE, d MMMM',
            ).format(widget.clock?.call() ?? DateTime.now()),
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A better day.\nOne great visit at a time.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _todayAppointments.isEmpty
                ? 'Your workspace is ready. Manage your queue, shop and customers here.'
                : '${_todayAppointments.length} appointments on today’s calendar. Let’s make every visit count.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _pulseMetric(
                  '${_todayAppointments.length}',
                  'Today',
                  Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pulseMetric(
                  '$queue',
                  'In queue',
                  Icons.people_alt_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pulseMetric(
                  '$completed',
                  'Completed',
                  Icons.done_all_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pulseMetric(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: KeshColors.proGold),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 48,
            height: 48,
            child:
                _shopPhotos.isEmpty
                    ? Container(
                      color: _ink,
                      child: const Icon(Icons.storefront, color: Colors.white),
                    )
                    : Image.network(
                      _shopPhotos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: _ink,
                          child: const Icon(
                            Icons.storefront,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              Text(
                _shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (_isProActive) ...[_buildProBadge(), const SizedBox(width: 6)],
        IconButton(
          onPressed: _openProfile,
          icon: const Icon(Icons.person_outline, color: _ink),
        ),
      ],
    );
  }

  Widget _buildProBadge() => Semantics(
    button: true,
    label: 'KeshKart Pro $_proExpiryLabel',
    child: Tooltip(
      message: 'KeshKart Pro $_proExpiryLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openSubscription,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE4B33B), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26091426),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 17,
                  color: Color(0xFFE4B33B),
                ),
                SizedBox(width: 4),
                Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<String> _validShopPhotos(List<String> photos) {
    return photos.where((photo) {
      final value = photo.trim();
      if (value.isEmpty || value.startsWith('shimmer_')) return false;
      return value.contains('/shop_photos/$_shopId/') ||
          value.contains('/shop_verifications/$_shopId/') ||
          value.startsWith('shop_photos/$_shopId/') ||
          value.startsWith('shop_verifications/$_shopId/');
    }).toList();
  }

  Future<List<String>> _resolveShopPhotos(List<String> photos) async {
    final resolved = <String>[];
    for (final photo in photos) {
      try {
        final refreshed = await BedrockClient().getDownloadUrl(photo);
        if (refreshed != null && refreshed.isNotEmpty) resolved.add(refreshed);
      } catch (_) {
        // Never render a stale signed URL. The next profile refresh can retry.
      }
    }
    return resolved;
  }

  Future<void> _refreshShopPhotos(List<String> photos) async {
    final resolved = await _resolveShopPhotos(photos);
    if (!mounted) return;
    setState(() => _shopPhotos = resolved);
  }

  Widget _buildOpenCard() {
    final canOpen = _isVerified;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _actionIcon(_isOpen ? Icons.lock_open_outlined : Icons.lock_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !canOpen
                      ? 'Shop verification required'
                      : _isOpen
                      ? 'Shop is open'
                      : 'Shop is closed',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  !canOpen
                      ? 'Submit a live shop photo from Profile and wait for approval.'
                      : _isOpen
                      ? 'Customers can book and check in.'
                      : 'Turn on when you are ready.',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: canOpen && _isOpen,
            activeThumbColor: _green,
            onChanged:
                canOpen ? _toggleOpen : (_) => _showVerificationRequired(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationNotice() {
    final status = _verificationStatus.toLowerCase();
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isRejected
                ? const Color(0xFFFFF1F1)
                : isPending
                ? const Color(0xFFFFF8E1)
                : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isRejected
                  ? const Color(0xFFFFCDD2)
                  : isPending
                  ? const Color(0xFFFFECB3)
                  : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRejected
                ? Icons.error_outline
                : isPending
                ? Icons.hourglass_top
                : Icons.verified_user_outlined,
            color:
                isRejected
                    ? Colors.red
                    : isPending
                    ? Colors.orange
                    : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isRejected
                  ? 'Shop verification was rejected. Submit a fresh live shop photo from Profile.'
                  : isPending
                  ? 'Shop verification is under review. Customers will see you after approval.'
                  : 'Verify your shop from Profile to appear in customer discovery.',
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final queue =
        _todayAppointments
            .where((doc) => ['arrived', 'in_progress'].contains(_status(doc)))
            .length;
    final completed =
        _todayAppointments
            .where(
              (doc) => ['completed', 'done', 'served'].contains(_status(doc)),
            )
            .length;
    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            'Today',
            '${_todayAppointments.length}',
            Icons.event_note,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _summaryTile('Queue', '$queue', Icons.groups_outlined)),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryTile('Done', '$completed', Icons.check_circle_outline),
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ink, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildNextAppointment() {
    final next =
        _upcomingAppointments.isEmpty ? null : _upcomingAppointments.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _actionIcon(Icons.schedule),
          const SizedBox(width: 12),
          Expanded(
            child:
                next == null
                    ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No upcoming slot',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'New bookings will appear here.',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(next['customerName'], fallback: 'Customer'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_timeLabel(next['slotStart'] ?? next['time'])} - ${_titleCase(_status(next))}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
          ),
          TextButton(onPressed: _openQueue, child: const Text('Queue')),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _HomeAction(Icons.qr_code_scanner, 'Check in', _openReceiptScanner),
      _HomeAction(Icons.groups_outlined, 'Live Queue', _openQueue),
      _HomeAction(Icons.design_services_outlined, 'Services', _openServices),
      _HomeAction(
        Icons.chair_outlined,
        'Seats',
        () => Navigator.push(context, slideUpRoute(const BarberSeatsScreen())),
      ),
      _HomeAction(Icons.person_outline, 'Profile', _openProfile),
      _HomeAction(
        Icons.workspace_premium_outlined,
        'KeshKart Pro',
        _openSubscription,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: KeshKartDesktopFrame.isWide(context) ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                _actionIcon(action.icon, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openInsights({bool customers = false}) {
    Navigator.push(
      context,
      slideUpRoute(BarberInsightsScreen(customersFirst: customers)),
    );
  }

  Widget _buildInsightsEntry() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFF1E8D8),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BEYOND TODAY',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
            color: KeshColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Build a shop they come back to.',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Understand repeat visits, busy hours, cancellations and your customer relationships.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _openInsights,
              icon: const Icon(Icons.insights),
              label: const Text('Explore insights'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openInsights(customers: true),
              icon: const Icon(Icons.people_outline),
              label: const Text('Customer book'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildAppointmentList() {
    if (_todayAppointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: const Text(
          'No appointments for today. Keep your shop open to receive bookings.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
      );
    }
    return Column(children: _todayAppointments.map(_appointmentTile).toList());
  }

  Widget _appointmentTile(Map<String, dynamic> doc) {
    final id = _text(doc['id'], fallback: _text(doc['_id']));
    final status = _status(doc);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _actionIcon(Icons.person_outline, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(doc['customerName'], fallback: 'Customer'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_timeLabel(doc['slotStart'] ?? doc['time'])} - ${_text(doc['service'], fallback: 'Service')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _statusPill(status),
            ],
          ),
          if (id.isNotEmpty &&
              [
                'booked',
                'scheduled',
                'confirmed',
                'arrived',
                'in_progress',
              ].contains(status)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (['booked', 'scheduled', 'confirmed'].contains(status))
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _updatingAppointments.contains(id)
                              ? null
                              : () =>
                                  _updateAppointment(id, {'status': 'arrived'}),
                      child: const Text('Arrived'),
                    ),
                  ),
                if (['arrived', 'in_progress'].contains(status))
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _updatingAppointments.contains(id)
                              ? null
                              : () => _updateAppointment(id, {
                                'status':
                                    status == 'arrived'
                                        ? 'in_progress'
                                        : 'completed',
                                if (status == 'in_progress') 'isDone': true,
                              }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        status == 'arrived'
                            ? 'Start service'
                            : 'Complete visit',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 18,
        fontWeight: FontWeight.w900,
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

  Widget _actionIcon(IconData icon, {double size = 44}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: _ink, size: size * 0.5),
    );
  }

  Widget _statusPill(String status) {
    final done = ['completed', 'done', 'served'].contains(status);
    final cancelled = status == 'cancelled';
    final color =
        cancelled
            ? const Color(0xFFE23A3A)
            : done
            ? const Color(0xFF009B63)
            : _ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _titleCase(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _updateAppointment(String id, Map<String, dynamic> data) async {
    if (_updatingAppointments.contains(id)) return;
    setState(() => _updatingAppointments.add(id));
    try {
      final result = await BedrockClient().updateDocument('appointments', id, {
        ...data,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Appointment was not updated. Please refresh and retry.',
              ),
            ),
          );
        }
        return;
      }
      await _loadTodayAppointments();
    } finally {
      if (mounted) setState(() => _updatingAppointments.remove(id));
    }
  }

  void _openProfile() {
    if (_shopId.isEmpty) return;
    Navigator.push(
      context,
      slideUpRoute(BarberProfileScreen(barberId: _shopId)),
    );
  }

  void _openQueue() {
    if (_shopId.isEmpty) return;
    Navigator.push(
      context,
      slideUpRoute(QueueManagementScreen(shopId: _shopId)),
    );
  }

  Future<void> _openReceiptScanner() async {
    if (_shopId.isEmpty) return;
    final checkedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => const BarberReceiptScannerScreen(),
      ),
    );
    if (checkedIn == true) await _loadTodayAppointments();
  }

  Future<void> _openSubscription() async {
    await Navigator.push(
      context,
      slideUpRoute(const BarberSubscriptionScreen()),
    );
    if (mounted) await _refreshSubscription();
  }

  void _openServices() {
    if (_shopId.isEmpty) return;
    Navigator.push(
      context,
      slideUpRoute(GroomingMenuScreen(barberId: _shopId)),
    );
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

  String _status(Map<String, dynamic> doc) {
    return _text(
      doc['status'],
      fallback: doc['isDone'] == true ? 'completed' : 'booked',
    ).toLowerCase();
  }

  String _timeLabel(dynamic value) {
    final millis = _millis(value);
    if (millis <= 0) return 'Time pending';
    return DateFormat(
      'h:mm a',
    ).format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  int _millis(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return DateTime.tryParse(value?.toString() ?? '')?.millisecondsSinceEpoch ??
        0;
  }

  String _titleCase(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Booked';
    return text
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

class _HomeAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeAction(this.icon, this.label, this.onTap);
}
