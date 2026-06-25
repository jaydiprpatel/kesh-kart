import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../bedrock_client.dart';

class KeshKartRealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({bool batching = true}) async {
    if (_channel != null) return;

    _shouldReconnect = true;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bedrock_token');
    final uri = _buildRealtimeUri(token: token, batching: batching);

    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready.timeout(const Duration(seconds: 10));
    } catch (error) {
      await channel.sink.close();
      _events.add({'type': 'socket_error', 'error': error.toString()});
      _channel = null;
      _scheduleReconnect();
      return;
    }

    _channel = channel;
    _reconnectAttempts = 0;
    _subscription = channel.stream.listen(
      _handleMessage,
      onError: (error) {
        _events.add({'type': 'socket_error', 'error': error.toString()});
        _scheduleReconnect();
      },
      onDone: _handleDone,
      cancelOnError: false,
    );
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void ping() {
    _send({'type': 'ping'});
  }

  void subscribeDocument(String documentId, {int? sinceVersion}) {
    _send({
      'type': 'subscribe',
      'document_id': documentId,
      if (sinceVersion != null) 'since_version': sinceVersion,
    });
  }

  void unsubscribeDocument(String documentId) {
    _send({'type': 'unsubscribe', 'document_id': documentId});
  }

  void subscribeQuery({
    required String subscriptionId,
    required String collection,
    required List<List<dynamic>> filters,
    List<Map<String, String>> orderBy = const [],
    int limit = 50,
  }) {
    _send({
      'type': 'subscribe_query',
      'subscription_id': subscriptionId,
      'collection': collection,
      'query': {'filters': filters, 'order_by': orderBy, 'limit': limit},
    });
  }

  void unsubscribeQuery(String subscriptionId) {
    _send({'type': 'unsubscribe_query', 'subscription_id': subscriptionId});
  }

  void patchDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> patch,
    String? requestId,
  }) {
    _send({
      'type': 'patch',
      'collection': collection,
      'document_id': documentId,
      'patch': patch,
      if (requestId != null) 'request_id': requestId,
    });
  }

  Uri _buildRealtimeUri({String? token, required bool batching}) {
    final base = Uri.parse(BedrockClient.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final authority = base.hasPort ? '${base.host}:${base.port}' : base.host;
    return Uri.parse('$scheme://$authority/ws/v1/realtime/').replace(
      queryParameters: {
        'project': BedrockClient.projectKey,
        'batch': batching ? '1' : '0',
        if (token != null && token.isNotEmpty) 'token': token,
      },
    );
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) {
      _events.add({'type': 'socket_error', 'error': 'not_connected'});
      return;
    }
    channel.sink.add(jsonEncode(message));
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message.toString());
      if (decoded is Map<String, dynamic>) {
        if (decoded['type'] == 'pong') {
          _reconnectAttempts = 0;
        }
        _events.add(decoded);
      }
    } catch (error) {
      _events.add({'type': 'decode_error', 'error': error.toString()});
    }
  }

  void _handleDone() {
    _events.add({'type': 'socket_closed'});
    _channel = null;
    _subscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectTimer != null) return;
    _channel = null;
    _subscription = null;
    final seconds = _reconnectAttempts < 5 ? 1 << _reconnectAttempts : 30;
    _reconnectAttempts += 1;
    _events.add({'type': 'socket_reconnecting', 'in_seconds': seconds});
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      _reconnectTimer = null;
      if (!_shouldReconnect) return;
      try {
        await connect();
        _events.add({'type': 'socket_reconnected'});
      } catch (error) {
        _events.add({'type': 'socket_error', 'error': error.toString()});
        _scheduleReconnect();
      }
    });
  }
}
