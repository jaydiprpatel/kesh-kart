import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kesh_kart/layout/keshkart_desktop_frame.dart';
import 'package:intl/intl.dart';
import '../bedrock_client.dart';
import '../services/realtime_service.dart';

class QueueManagementScreen extends StatefulWidget {
  final String shopId;

  const QueueManagementScreen({super.key, required this.shopId});

  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen> {
  Timer? _pollingTimer;
  final KeshKartRealtimeService _realtime = KeshKartRealtimeService();
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  String? _error;
  bool _isOffline = false;
  bool _isRealtimeConnected = false;
  final Set<String> _pendingStatusUpdates = {};

  @override
  void initState() {
    super.initState();
    _fetchQueue();
    _startRealtime();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchQueue(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeSub?.cancel();
    _realtime.disconnect();
    super.dispose();
  }

  Future<void> _startRealtime() async {
    _realtimeSub = _realtime.events.listen(_handleRealtimeEvent);
    try {
      await _realtime.connect();
      _realtime.ping();
      _subscribeRealtimeQueue();
      if (mounted) {
        setState(() {
          _isRealtimeConnected = true;
          _isOffline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRealtimeConnected = false;
          _isOffline = true;
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
        setState(() {
          _isRealtimeConnected = true;
          _isOffline = false;
        });
      }
      return;
    }

    if (type == 'socket_closed' ||
        type == 'socket_error' ||
        type == 'socket_reconnecting') {
      if (mounted) {
        setState(() {
          _isRealtimeConnected = false;
          _isOffline = true;
        });
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
            _appointments = normalized;
            _isLoading = false;
            _isRealtimeConnected = true;
            _isOffline = false;
          });
        }
      }
      return;
    }

    if (type == 'document_change') {
      _mergeRealtimeChange(event);
    }
  }

  void _subscribeRealtimeQueue() {
    _realtime.subscribeQuery(
      subscriptionId: 'barber-live-queue-${widget.shopId}',
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

  void _mergeRealtimeChange(Map<String, dynamic> event) {
    final docId = (event['document_id'] ?? event['id'])?.toString();
    if (docId == null || docId.isEmpty) return;
    final delta = event['delta'];
    if (delta is! Map<String, dynamic>) return;
    if (delta['shopId'] != null && delta['shopId'] != widget.shopId) return;

    if (mounted) {
      setState(() {
        final index = _appointments.indexWhere((doc) {
          final id = doc['id'] ?? doc['_id'];
          return id?.toString() == docId;
        });

        final existing =
            index >= 0 ? _appointments[index] : <String, dynamic>{};
        final merged = {
          ...existing,
          ...delta,
          'id': docId,
          if (event['version'] != null) 'version': event['version'],
        };

        if (_isVisibleQueueDoc(merged)) {
          if (index >= 0) {
            _appointments[index] = merged;
          } else {
            _appointments.add(merged);
          }
        } else if (index >= 0) {
          _appointments.removeAt(index);
        }
      });
    }
  }

  Future<void> _fetchQueue() async {
    try {
      final now = DateTime.now();

      final response = await BedrockClient().queryCollection(
        'appointments',
        params: {'shopId': widget.shopId},
      );

      // Bedrock returns a list of docs. Filter locally for now for MVP:
      final validStatus = ['booked', 'arrived', 'in_progress'];
      final startOfDayMillis =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final endOfDayMillis = startOfDayMillis + 86400000;

      final filtered =
          response
              .where((doc) {
                if (doc is! Map<String, dynamic>) return false;
                if (!validStatus.contains(doc['status'])) return false;
                final slotStart = _millisFromValue(doc['slotStart']);
                return slotStart >= startOfDayMillis &&
                    slotStart < endOfDayMillis;
              })
              .map((e) => e as Map<String, dynamic>)
              .toList();

      if (mounted) {
        setState(() {
          _appointments = filtered;
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    }
  }

  bool _isVisibleQueueDoc(Map<String, dynamic> doc) {
    final validStatus = ['booked', 'arrived', 'in_progress'];
    if (doc['shopId'] != widget.shopId) return false;
    if (!validStatus.contains(doc['status'])) return false;
    final now = DateTime.now();
    final startOfDayMillis =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDayMillis = startOfDayMillis + 86400000;
    final slotStart = _millisFromValue(doc['slotStart']);
    return slotStart >= startOfDayMillis && slotStart < endOfDayMillis;
  }

  int _millisFromValue(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  int _getStatusPriority(String status) {
    switch (status) {
      case 'in_progress':
        return 1;
      case 'arrived':
        return 2;
      case 'booked':
        return 3;
      default:
        return 99; // no_show, completed, etc. usually filtered out or placed last
    }
  }

  Future<void> _updateAppointmentStatus(
    String appointmentId,
    String newStatus, {
    Map<String, dynamic> extraData = const {},
  }) async {
    if (_pendingStatusUpdates.contains(appointmentId)) return;
    setState(() {
      _pendingStatusUpdates.add(appointmentId);
    });

    final int newPriority = _getStatusPriority(newStatus);
    final now = DateTime.now().toIso8601String();

    Map<String, dynamic> updateData = {
      'status': newStatus,
      'priority': newPriority,
      ...extraData,
    };

    if (newStatus == 'arrived') updateData['arrivedAt'] = now;
    if (newStatus == 'in_progress') updateData['startedAt'] = now;
    if (newStatus == 'completed') updateData['completedAt'] = now;

    try {
      final result = await BedrockClient().updateDocument(
        'appointments',
        appointmentId,
        updateData,
      );
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update failed. Please try again.')),
        );
      }
      await _fetchQueue();
    } finally {
      if (mounted) {
        setState(() {
          _pendingStatusUpdates.remove(appointmentId);
        });
      }
    }
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    final reason = await _askReason(
      title: 'Cancel booking',
      label: 'Reason for customer',
      fallback: 'Barber is unavailable for this appointment.',
    );
    if (reason == null) return;
    await _updateAppointmentStatus(
      appointmentId,
      'cancelled_by_barber',
      extraData: {
        'cancelledBy': 'barber',
        'cancelReason': reason,
        'cancelledAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> _rescheduleAppointment(
    String appointmentId,
    Map<String, dynamic> data,
  ) async {
    final current = _millisFromValue(data['slotStart']);
    final initial =
        current > 0
            ? DateTime.fromMillisecondsSinceEpoch(current)
            : DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final reason = await _askReason(
      title: 'Reschedule booking',
      label: 'Reason for customer',
      fallback: 'Barber requested a different slot.',
    );
    if (reason == null) return;

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final end = start.add(const Duration(minutes: 30));
    await _updateAppointmentStatus(
      appointmentId,
      'booked',
      extraData: {
        'slotStart': start.millisecondsSinceEpoch,
        'slotEnd': end.millisecondsSinceEpoch,
        'rescheduledBy': 'barber',
        'rescheduleReason': reason,
        'rescheduledAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<String?> _askReason({
    required String title,
    required String label,
    required String fallback,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context, text.isEmpty ? fallback : text);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Queue'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              _isRealtimeConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isRealtimeConnected ? Colors.green : Colors.orange,
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchQueue),
        ],
      ),
      body: KeshKartDesktopFrame(maxWidth: 1050, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return Column(
      children: [
        if (_isOffline)
          Container(
            width: double.infinity,
            color: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Text(
              'Connection lost. Queue may be outdated.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (_appointments.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                "No appointments currently in queue.",
                style: TextStyle(fontSize: 16),
              ),
            ),
          )
        else
          Expanded(
            child: Builder(
              builder: (context) {
                final sortedDocs = List<Map<String, dynamic>>.from(
                  _appointments,
                )..sort((a, b) {
                  final priorityA = _getStatusPriority(
                    a['status'] ?? 'unknown',
                  );
                  final priorityB = _getStatusPriority(
                    b['status'] ?? 'unknown',
                  );

                  if (priorityA != priorityB) {
                    return priorityA.compareTo(priorityB);
                  }

                  if (a['status'] == 'arrived') {
                    final arrA =
                        DateTime.tryParse(a['arrivedAt']?.toString() ?? '') ??
                        DateTime.now();
                    final arrB =
                        DateTime.tryParse(b['arrivedAt']?.toString() ?? '') ??
                        DateTime.now();
                    return arrA.compareTo(arrB);
                  }

                  final startA =
                      a['slotStart'] is int
                          ? DateTime.fromMillisecondsSinceEpoch(a['slotStart'])
                          : (DateTime.tryParse(
                                a['slotStart']?.toString() ?? '',
                              ) ??
                              DateTime.now());
                  final startB =
                      b['slotStart'] is int
                          ? DateTime.fromMillisecondsSinceEpoch(b['slotStart'])
                          : (DateTime.tryParse(
                                b['slotStart']?.toString() ?? '',
                              ) ??
                              DateTime.now());
                  return startA.compareTo(startB);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final data = sortedDocs[index];
                    final id = data['id'] ?? data['_id'] ?? 'unknown_id';
                    return _buildQueueCard(id, data, index + 1);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQueueCard(
    String appointmentId,
    Map<String, dynamic> data,
    int position,
  ) {
    final status = data['status'] ?? 'unknown';
    final isPending = _pendingStatusUpdates.contains(appointmentId);

    DateTime? slotStart;
    if (data['slotStart'] is int) {
      slotStart = DateTime.fromMillisecondsSinceEpoch(data['slotStart']);
    } else if (data['slotStart'] != null) {
      slotStart = DateTime.tryParse(data['slotStart'].toString());
    }

    final timeStr =
        slotStart != null ? DateFormat.jm().format(slotStart) : 'Unknown Time';
    final customerName = data['customerName'] ?? 'Customer';
    final locationUnverified = data['location_unverified'] ?? false;
    final isLate = data['late'] ?? false;

    Color cardColor;
    switch (status) {
      case 'in_progress':
        cardColor = Colors.blue.shade50;
        break;
      case 'arrived':
        cardColor = Colors.green.shade50;
        break;
      default:
        cardColor = Colors.white;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: status == 'in_progress' ? 4 : 1,
      child: ExpansionTile(
        title: Row(
          children: [
            if (status == 'in_progress')
              const Icon(Icons.content_cut, color: Colors.blue)
            else if (status == 'arrived')
              const Icon(Icons.check_circle, color: Colors.green)
            else
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  '$position',
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(timeStr, style: const TextStyle(color: Colors.grey)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Status: ${status.toUpperCase()}'),
                if (isLate) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LATE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (locationUnverified && status == 'arrived') ...[
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Location Unverified',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children:
                  isPending
                      ? const [CircularProgressIndicator()]
                      : _buildActionButtons(appointmentId, status, data),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(
    String id,
    String status,
    Map<String, dynamic> data,
  ) {
    if (status == 'booked') {
      return [
        OutlinedButton.icon(
          onPressed: () => _rescheduleAppointment(id, data),
          icon: const Icon(Icons.event_repeat),
          label: const Text('Reschedule'),
        ),
        ElevatedButton.icon(
          onPressed: () => _updateAppointmentStatus(id, 'arrived'),
          icon: const Icon(Icons.check),
          label: const Text('Mark Arrived'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        TextButton.icon(
          onPressed: () => _updateAppointmentStatus(id, 'no_show'),
          icon: const Icon(Icons.person_off),
          label: const Text('No Show'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
        TextButton.icon(
          onPressed: () => _cancelAppointment(id),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
      ];
    } else if (status == 'arrived') {
      return [
        ElevatedButton.icon(
          onPressed: () => _updateAppointmentStatus(id, 'in_progress'),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Service'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ];
    } else if (status == 'in_progress') {
      return [
        ElevatedButton.icon(
          onPressed: () => _updateAppointmentStatus(id, 'completed'),
          icon: const Icon(Icons.done_all),
          label: const Text('Complete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ];
    }
    return [];
  }
}
