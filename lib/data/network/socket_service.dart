import 'dart:async';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal() {
    debugPrint('[SOCKET_DEBUG] Socket CREATED');
  }

  static String _getSocketCaller() {
    final frames = StackTrace.current.toString().split('\n');
    for (final frame in frames) {
      if (frame.contains('package:catch_watch/') && !frame.contains('socket_service.dart')) {
        return frame.trim();
      }
    }
    return 'Unknown caller';
  }

  io.Socket? _socket;
  bool _isConnected = false;
  bool _isAuthBlocked = false;
  String? _blockedToken;
  VoidCallback? onAccountDisabled;

  final StreamController<Map<String, dynamic>> _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  bool get isConnected => _isConnected;
  bool get isAuthBlocked => _isAuthBlocked;

  void resetAuthBlock() {
    _isAuthBlocked = false;
    _blockedToken = null;
  }

  void connect() {
    debugPrint('[SOCKET_DEBUG] Socket CONNECT called from: ${_getSocketCaller()}');
    final token = HiveService.getToken();
    if (token == null) {
      debugPrint('Socket.io Connection deferred: No token found');
      return;
    }

    if (_isAuthBlocked && _blockedToken == token) {
      debugPrint('[SOCKET] Connection attempt suppressed: Account is disabled or token invalid.');
      return;
    }

    if (_isConnected && _socket != null) return;

    String serverUrl = AppUrl.serverUrl.trim();
    
    debugPrint('Socket.io Connecting to $serverUrl...');

    try {
      _socket = io.io(serverUrl, io.OptionBuilder()
        .setTransports(['websocket']) // Use WebSocket transport
        .disableAutoConnect()         // Disable auto-connection
        .setReconnectionAttempts(3)   // Stop endless reconnect loops on failure
        .setReconnectionDelay(2000)
        .setQuery({'token': token})    // Pass token as query parameter
        .build());

      _socket!.connect();

      _socket!.onConnect((_) {
        _isConnected = true;
        _isAuthBlocked = false;
        _blockedToken = null;
        debugPrint('[SOCKET_DEBUG] Socket.io Connected');
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('[SOCKET_DEBUG] Socket.io Disconnected');
      });

      void handlePermanentAuthError(dynamic data) {
        final msg = data?.toString() ?? '';
        debugPrint('Socket.io Error: $msg');
        if (msg.contains('Account disabled') ||
            msg.contains('Authentication error') ||
            msg.contains('jwt expired') ||
            msg.contains('invalid token')) {
          debugPrint('[SOCKET] Permanent auth failure detected: $msg. Disconnecting and stopping reconnection.');
          _isAuthBlocked = true;
          _blockedToken = token;
          _socket?.disconnect();
          _socket?.dispose();
          _socket = null;
          _isConnected = false;
          onAccountDisabled?.call();
        }
      }

      _socket!.onConnectError((data) {
        handlePermanentAuthError(data);
      });

      _socket!.onError((data) {
        handlePermanentAuthError(data);
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

  void disconnect({bool clearAuthBlock = false}) {
    debugPrint('[SOCKET_DEBUG] Socket DISCONNECT called from: ${_getSocketCaller()}');
    if (clearAuthBlock) {
      _isAuthBlocked = false;
      _blockedToken = null;
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    debugPrint('[SOCKET_DEBUG] Socket DISPOSE called from: ${_getSocketCaller()}');
    disconnect(clearAuthBlock: true);
    _messageStreamController.close();
  }
}
