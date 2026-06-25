import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kesh_kart/barber/profile.dart';
import 'package:kesh_kart/barber/queue_management_screen.dart';
import 'package:kesh_kart/barber/service.dart';
import 'package:kesh_kart/barber/shop_qr_generator_screen.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/realtime_service.dart';
import 'dart:async';

class BarberHome extends StatefulWidget {
  const BarberHome({super.key});

  @override
  State<BarberHome> createState() => _BarberHomeState();
}

class _BarberHomeState extends State<BarberHome> {
  static const Color _ink = Color(0xFF091426);
  static const Color _muted = Color(0xFF54647A);
  static const Color _green = Color(0xFF00D084);

  final KeshKartRealtimeService _realtime = KeshKartRealtimeService();
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  bool _isLoading = true;
  bool _isOpen = false;
  String _shopId = '';
  String _shopName = 'Barber';
  String _verificationStatus = 'unverified';
  List<String> _shopPhotos = [];
  List<Map<String, dynamic>> _todayAppointments = [];

  bool get _isVerified => _verificationStatus.toLowerCase() == 'approved';

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
          if (mounted) {
            setState(() {
              if (delta.containsKey('verificationStatus')) {
                _verificationStatus =
                    delta['verificationStatus']?.toString() ?? 'unverified';
              }
              if (delta.containsKey('isActive')) {
                _isOpen = delta['isActive'] == true || delta['isOpen'] == true;
              } else if (delta.containsKey('isOpen')) {
                _isOpen = delta['isOpen'] == true;
              }
              if (delta.containsKey('shopName')) {
                _shopName = delta['shopName']?.toString() ?? _shopName;
              }
              if (delta.containsKey('shopPhotos')) {
                final photos = delta['shopPhotos'];
                if (photos is List) {
                  _shopPhotos = _validShopPhotos(
                    photos.whereType<String>().toList(),
                  );
                }
              }
            });
          }
        }
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _shopId =
        prefs.getString('bedrock_user_id') ?? prefs.getString('userId') ?? '';
    _shopName = prefs.getString('barberName') ?? 'Barber';
    _isOpen = prefs.getBool('isActive') ?? false;
    _shopPhotos = _validShopPhotos(prefs.getStringList('shopPhotos') ?? []);

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
        if (!_isVerified) {
          _isOpen = false;
          await prefs.setBool('isActive', false);
        }
        final photos = profile['shopPhotos'];
        if (photos is List) {
          _shopPhotos = _validShopPhotos(photos.whereType<String>().toList());
        }
      }
      if (_realtime.isConnected) {
        _realtime.subscribeDocument(_shopId);
      }
      await _loadTodayAppointments(setLoading: false);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
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
    final docs =
        rows.map(_unwrapData).where((doc) => doc.isNotEmpty).where((doc) {
            final slot = _millis(doc['slotStart'] ?? doc['time']);
            return slot >= start && slot < end;
          }).toList()
          ..sort(
            (a, b) => _millis(
              a['slotStart'] ?? a['time'],
            ).compareTo(_millis(b['slotStart'] ?? b['time'])),
          );
    if (!mounted) return;
    setState(() => _todayAppointments = docs);
  }

  Future<void> _toggleOpen(bool value) async {
    if (value && !_isVerified) {
      _showVerificationRequired();
      return;
    }
    setState(() => _isOpen = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isActive', value);
    if (_shopId.isNotEmpty) {
      await BedrockClient().updateDocument('users', _shopId, {
        'isActive': value,
        'isOpen': value,
      });
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
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                    onRefresh: _loadDashboard,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        if (_verificationStatus.toLowerCase() !=
                            'approved') ...[
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
                      ],
                    ),
                  ),
        ),
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
        IconButton(
          onPressed: _openProfile,
          icon: const Icon(Icons.person_outline, color: _ink),
        ),
      ],
    );
  }

  List<String> _validShopPhotos(List<String> photos) {
    return photos.where((photo) {
      final value = photo.trim();
      if (value.isEmpty || value.startsWith('shimmer_')) return false;
      return value.contains('/shop_photos/$_shopId/') ||
          value.contains('/shop_verifications/$_shopId/');
    }).toList();
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
            'Bookings',
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final upcoming =
        _todayAppointments
            .where((doc) => _millis(doc['slotStart'] ?? doc['time']) >= now)
            .toList();
    final next = upcoming.isEmpty ? null : upcoming.first;
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
      _HomeAction(Icons.qr_code_2, 'Shop QR', _openQr),
      _HomeAction(Icons.groups_outlined, 'Live Queue', _openQueue),
      _HomeAction(Icons.design_services_outlined, 'Services', _openServices),
      _HomeAction(Icons.person_outline, 'Profile', _openProfile),
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
              ![
                'completed',
                'done',
                'served',
                'cancelled',
              ].contains(status)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        () => _updateAppointment(id, {'status': 'arrived'}),
                    child: const Text('Arrived'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        () => _updateAppointment(id, {
                          'status': 'completed',
                          'isDone': true,
                        }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Complete'),
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
    await BedrockClient().updateDocument('appointments', id, {
      ...data,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _loadTodayAppointments();
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

  void _openQr() {
    if (_shopId.isEmpty) return;
    Navigator.push(
      context,
      slideUpRoute(ShopQrGeneratorScreen(shopId: _shopId)),
    );
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
