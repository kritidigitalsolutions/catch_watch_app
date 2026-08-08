import 'dart:convert';
import 'dart:async';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  final StreamController<Map<String, dynamic>> _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;

  void connect() {
    final token = HiveService.getToken();
    if (token == null) {
      debugPrint('WebSocket Connection deferred: No token found');
      _reconnect();
      return;
    }

    if (_isConnected) return;

    // Convert http(s):// to ws(s)://
    String wsUrl = AppUrl.serverUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse("$wsUrl?token=$token");

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      debugPrint('WebSocket Connected to $uri');

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageStreamController.add(data);
          } catch (e) {
            debugPrint('Error decoding socket message: $e');
          }
        },
        onDone: () {
          debugPrint('WebSocket Disconnected');
          _isConnected = false;
          _reconnect();
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          _isConnected = false;
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket Connection Error: $e');
      _isConnected = false;
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void sendMessage(String event, Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      final payload = jsonEncode({
        'event': event,
        'data': data,
      });
      _channel!.sink.add(payload);
    } else {
      debugPrint('Cannot send message: WebSocket not connected');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageStreamController.close();
  }
}
