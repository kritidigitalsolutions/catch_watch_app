import 'dart:async';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  final StreamController<Map<String, dynamic>> _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    final token = HiveService.getToken();
    if (token == null) {
      debugPrint('Socket.io Connection deferred: No token found');
      return;
    }

    if (_isConnected && _socket != null) return;

    String serverUrl = AppUrl.serverUrl.trim();
    
    debugPrint('Socket.io Connecting to $serverUrl...');

    try {
      _socket = io.io(serverUrl, io.OptionBuilder()
        .setTransports(['websocket']) // Use WebSocket transport
        .disableAutoConnect()         // Disable auto-connection
        .setQuery({'token': token})    // Pass token as query parameter
        .build());

      _socket!.connect();

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('Socket.io Connected');
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('Socket.io Disconnected');
      });

      _socket!.onConnectError((data) {
        debugPrint('Socket.io Connection Error: $data');
      });

      _socket!.onError((data) {
        debugPrint('Socket.io Error: $data');
      });

      // Listen to all common chat and call events and pipe them to the stream
      final events = [
        'new_message', 'receive_message', 'message',
        'status_update', 'user_status',
        'message_read', 'read_receipt', 'READ_RECEIPT',
        'message_delivered', 'delivered_receipt', 'DELIVERED_RECEIPT',
        'user_blocked',
        'message_reaction', 'new_reaction', 'reaction',
        'incoming_call', 'call_accepted', 'call_rejected', 'call_ended', 
        'call_cancelled', 'call_busy', 'call_missed'
      ];

      for (var event in events) {
        _socket!.on(event, (data) {
          debugPrint('Socket.io Event: $event received');
          _messageStreamController.add({
            'event': event,
            'data': data,
          });
        });
      }

    } catch (e) {
      debugPrint('Socket.io Connection Exception: $e');
    }
  }

  void sendMessage(String event, Map<String, dynamic> data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
    } else {
      debugPrint('Cannot send message: Socket.io not connected');
      connect();
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageStreamController.close();
  }
}
