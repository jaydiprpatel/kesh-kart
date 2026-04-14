import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kesh_kart/backend/config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class BaasRealtime {
  static final BaasRealtime instance = BaasRealtime._private();
  BaasRealtime._private();

  WebSocketChannel? _channel;
  final Map<String, StreamController<dynamic>> _subscribers = {};
  bool _isConnected = false;

  Future<void> connect() async {
    if (_isConnected) return;
    try {
      final uri = Uri.parse(BaasConfig.wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to be established
      _isConnected = true;
      debugPrint("🔍 Platform: $defaultTargetPlatform, Web: $kIsWeb");
      debugPrint("✅ Connected to Baas Realtime: ${BaasConfig.wsUrl}");

      _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onDone: () {
          debugPrint("⚠️ WebSocket Disconnected");
          _isConnected = false;
          _reconnect();
        },
        onError: (e) {
          debugPrint("❌ WebSocket Error: $e");
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint("❌ WebSocket Connection Failed: $e");
      _isConnected = false;
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () => connect());
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      final String? type = message['type'];
      final String? queryId = message['queryId'];

      if (type == 'snapshot' && queryId != null) {
        if (_subscribers.containsKey(queryId)) {
          _subscribers[queryId]!.add(message['data']);
        }
      }
    } catch (e) {
      debugPrint("Error parsing WS message: $e");
    }
  }

  Stream<dynamic> subscribe(String collection, Map<String, dynamic> filters) {
    if (!_isConnected) connect();

    final queryId =
        "$collection-${jsonEncode(filters, toEncodable: _customEncoder)}-${DateTime.now().millisecondsSinceEpoch}";
    final controller = StreamController<dynamic>(
      onCancel: () {
        _subscribers.remove(queryId);
        // Optional: Send 'unsubscribe' message to server
      },
    );

    _subscribers[queryId] = controller;

    // Send generic subscribe message
    _send({
      "action": "subscribe",
      "queryId": queryId,
      "collection": collection,
      "filters": filters,
    });

    return controller.stream;
  }

  void _send(Map<String, dynamic> message) {
    if (_channel != null) {
      try {
        final payload = jsonEncode(message, toEncodable: _customEncoder);
        debugPrint("Sending WS Message: $payload");
        _channel!.sink.add(payload);
      } catch (e) {
        debugPrint("❌ Error sending WS message: $e");
      }
    } else {
      debugPrint("Cannot send, channel is null.");
    }
  }

  Object? _customEncoder(Object? item) {
    if (item is DateTime) {
      return item.toIso8601String();
    }
    // Add other types like GeoPoint if needed
    return item;
  }

  Future<String> diagnoseConnection() async {
    if (_isConnected) {
      return "✅ Connected to ${BaasConfig.wsUrl}";
    }

    try {
      debugPrint("⚠️ Not connected. Attempting to connect...");
      await connect();
      // Give it a moment to establish
      await Future.delayed(const Duration(milliseconds: 500));

      if (_isConnected) {
        return "✅ Successfully reconnected to ${BaasConfig.wsUrl}";
      } else {
        return "❌ Failed to connect to ${BaasConfig.wsUrl}. Check server status.";
      }
    } catch (e) {
      return "❌ Connection diagnostic failed: $e";
    }
  }
}
