import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/check_in_service.dart';
import '../services/realtime_service.dart';
import '../bedrock_client.dart';

class CheckInStatusScreen extends StatefulWidget {
  final String shopId;

  const CheckInStatusScreen({super.key, required this.shopId});

  @override
  State<CheckInStatusScreen> createState() => _CheckInStatusScreenState();
}

class _CheckInStatusScreenState extends State<CheckInStatusScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String _errorMessage = '';
  bool _isCheckingIn = false;
  bool _isRealtimeConnected = false;

  String _appointmentId = '';
  bool _locationUnverified = false;

  Timer? _pollingTimer;
  final KeshKartRealtimeService _realtime = KeshKartRealtimeService();
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  List<Map<String, dynamic>> _queueDocs = [];
  bool _isQueueLoading = true;

  @override
  void initState() {
    super.initState();
    _processCheckIn();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeSub?.cancel();
    _realtime.disconnect();
    super.dispose();
  }

  Future<void> _processCheckIn() async {
    if (_isCheckingIn) return;
    _isCheckingIn = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId =
          prefs.getString('bedrock_user_id') ?? prefs.getString('userId');
      if (userId == null || userId.isEmpty) {
        setState(() {
          _errorMessage = "You must be logged in.";
          _isLoading = false;
        });
        return;
      }

      final now = DateTime.now();
      final tenMinutesAgoMillis =
          now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;

      final responseDocs = await BedrockClient().queryCollection(
        'appointments',
        params: {'customerId': userId, 'shopId': widget.shopId},
      );

      final validStatus = ['booked', 'arrived', 'in_progress'];
      final validAppointments =
          responseDocs.where((doc) {
            if (!validStatus.contains(doc['status'])) return false;
            int slotEnd = 0;
            if (doc['slotEnd'] is int) {
              slotEnd = doc['slotEnd'];
            } else if (doc['slotEnd'] is String) {
              slotEnd =
                  DateTime.tryParse(doc['slotEnd'])?.millisecondsSinceEpoch ??
                  0;
            }
            return slotEnd >= tenMinutesAgoMillis;
          }).toList();

      if (validAppointments.isEmpty) {
        setState(() {
          _errorMessage = "No upcoming appointments found for this shop.";
          _isLoading = false;
        });
        return;
      }

      // Sort by slotEnd to get the closest one
      validAppointments.sort((a, b) {
        int endA =
            a['slotEnd'] is int
                ? a['slotEnd']
                : (DateTime.tryParse(
                      a['slotEnd']?.toString() ?? '',
                    )?.millisecondsSinceEpoch ??
                    0);
        int endB =
            b['slotEnd'] is int
                ? b['slotEnd']
                : (DateTime.tryParse(
                      b['slotEnd']?.toString() ?? '',
                    )?.millisecondsSinceEpoch ??
                    0);
        return endA.compareTo(endB);
      });

      final firstDoc = validAppointments.first;
      _appointmentId = firstDoc['id'] ?? firstDoc['_id'];

      final response = await CheckInService.checkIn(
        shopId: widget.shopId,
        appointmentId: _appointmentId,
      );

      if (mounted) {
        setState(() {
          if (response.success) {
            _isSuccess = true;
            _locationUnverified = response.locationUnverified;
            _startQueuePolling();
            _startRealtime();
          } else {
            _errorMessage = response.errorMessage ?? "An error occurred.";
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      _isCheckingIn = false;
    }
  }

  Future<void> _startRealtime() async {
    _realtimeSub ??= _realtime.events.listen(_handleRealtimeEvent);
    try {
      await _realtime.connect();
      _realtime.ping();
      _subscribeRealtimeQueue();
      if (mounted) {
        setState(() {
          _isRealtimeConnected = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRealtimeConnected = false;
        });
      }
    }
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
      if (type == 'socket_reconnected') {
        _subscribeRealtimeQueue();
      }
      if (mounted) {
        setState(() => _isRealtimeConnected = true);
      }
      return;
    }

    if (type == 'socket_closed' ||
        type == 'socket_error' ||
        type == 'socket_reconnecting') {
      if (mounted) {
        setState(() => _isRealtimeConnected = false);
      }
      return;
    }

    if (type == 'snapshot') {
      final docId = event['document_id']?.toString();
      final data = event['data'];
      if (docId == _appointmentId && data is Map<String, dynamic>) {
        _mergeQueueDoc({'id': docId, ...data});
      }
      return;
    }

    if (type == 'query_snapshot') {
      final docs = event['docs'];
      if (docs is List) {
        final normalized =
            docs
                .whereType<Map<String, dynamic>>()
                .map(_normalizeRealtimeDoc)
                .where(_isVisibleQueueDoc)
                .toList();
        if (mounted) {
          setState(() {
            _queueDocs = normalized;
            _isQueueLoading = false;
          });
        }
      }
      return;
    }

    if (type == 'document_change') {
      final docId = event['document_id']?.toString();
      final delta = event['delta'];
      if (docId == null || delta is! Map<String, dynamic>) return;
      _mergeQueueDoc({'id': docId, ...delta});
    }
  }

  void _subscribeRealtimeQueue() {
    if (_appointmentId.isNotEmpty) {
      _realtime.subscribeDocument(_appointmentId);
    }
    _realtime.subscribeQuery(
      subscriptionId: 'customer-live-queue-${widget.shopId}',
      collection: 'appointments',
      filters: [
        ['shopId', '==', widget.shopId],
      ],
      limit: 100,
    );
  }

  Map<String, dynamic> _normalizeRealtimeDoc(Map<String, dynamic> doc) {
    final data = doc['data'];
    if (data is Map<String, dynamic>) {
      return {
        ...data,
        'data': data,
        'id': doc['id'] ?? doc['document_id'],
        if (doc['version'] != null) 'version': doc['version'],
      };
    }
    return doc;
  }

  void _mergeQueueDoc(Map<String, dynamic> patch) {
    final docId = patch['id']?.toString();
    if (docId == null || docId.isEmpty) return;
    if (patch['shopId'] != null && patch['shopId'] != widget.shopId) return;

    if (mounted) {
      setState(() {
        final index = _queueDocs.indexWhere((doc) {
          final id = doc['id'] ?? doc['_id'];
          return id?.toString() == docId;
        });
        final existing = index >= 0 ? _queueDocs[index] : <String, dynamic>{};
        final merged = {...existing, ...patch, 'id': docId};

        if (_isVisibleQueueDoc(merged)) {
          if (index >= 0) {
            _queueDocs[index] = merged;
          } else {
            _queueDocs.add(merged);
          }
        } else if (index >= 0) {
          _queueDocs.removeAt(index);
        }
      });
    }
  }

  void _startQueuePolling() {
    _fetchQueue();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchQueue(),
    );
  }

  Future<void> _fetchQueue() async {
    try {
      final startOfDayMillis =
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ).millisecondsSinceEpoch;

      final responseDocs = await BedrockClient().queryCollection(
        'appointments',
        params: {'shopId': widget.shopId},
      );

      final validStatus = ['arrived', 'in_progress'];
      final filtered =
          responseDocs
              .where((doc) {
                if (doc is! Map<String, dynamic>) return false;
                if (!validStatus.contains(doc['status'])) return false;
                final slotStart = _millisFromValue(doc['slotStart']);
                return slotStart >= startOfDayMillis;
              })
              .map((e) => e as Map<String, dynamic>)
              .toList();

      if (mounted) {
        setState(() {
          _queueDocs = filtered;
          _isQueueLoading = false;
        });
      }
    } catch (e) {
      // Ignore polling errors silently for now, rely on next tick
    }
  }

  bool _isVisibleQueueDoc(Map<String, dynamic> doc) {
    final validStatus = ['arrived', 'in_progress'];
    if (doc['shopId'] != widget.shopId) return false;
    if (!validStatus.contains(doc['status'])) return false;
    final startOfDayMillis =
        DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ).millisecondsSinceEpoch;
    return _millisFromValue(doc['slotStart']) >= startOfDayMillis;
  }

  int _millisFromValue(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Queue Status'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              _isRealtimeConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isRealtimeConnected ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
      body: Center(
        child:
            _isLoading
                ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Processing check-in...'),
                  ],
                )
                : _isSuccess
                ? _buildLiveQueueView()
                : _buildErrorView(),
      ),
    );
  }

  Widget _buildLiveQueueView() {
    if (_isQueueLoading) {
      return const CircularProgressIndicator();
    }

    final sortedDocs = List<Map<String, dynamic>>.from(_queueDocs)..sort((
      a,
      b,
    ) {
      int priority(String st) => st == 'in_progress' ? 1 : 2;
      final pA = priority(a['status'] ?? '');
      final pB = priority(b['status'] ?? '');

      if (pA != pB) return pA.compareTo(pB);

      final arrA =
          DateTime.tryParse(a['arrivedAt']?.toString() ?? '') ?? DateTime.now();
      final arrB =
          DateTime.tryParse(b['arrivedAt']?.toString() ?? '') ?? DateTime.now();
      return arrA.compareTo(arrB);
    });

    int myIndex = -1;
    String nowServing = "No one currently in progress";

    for (int i = 0; i < sortedDocs.length; i++) {
      final doc = sortedDocs[i];
      if (doc['status'] == 'in_progress') {
        nowServing = doc['customerName'] ?? 'Customer';
      }

      final docId = doc['id'] ?? doc['_id'];
      if (docId == _appointmentId) {
        myIndex = i;
      }
    }

    if (myIndex == -1) {
      return const Center(child: Text('You are not in the queue.'));
    }

    final myPosition = myIndex + 1;
    final waitTime = myIndex * 15;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          const Text(
            "You're in the Queue!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),

          Card(
            elevation: 8,
            shadowColor: Colors.blue.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'LIVE QUEUE',
                    style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Now Serving: $nowServing',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const Divider(height: 40, color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Your Position',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '#$myPosition',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 60, color: Colors.white24),
                      Column(
                        children: [
                          const Text(
                            'Est. Wait',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '~$waitTime m',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_locationUnverified) ...[
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Location unverified. The barber may need to manually confirm your presence.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Check-in Failed',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
