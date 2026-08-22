import 'dart:convert';
import 'dart:io';

import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/data/network/socket_service.dart';
import 'package:catch_watch/models/chat_model.dart';
import 'package:catch_watch/repository/chat_repository.dart';
import 'package:catch_watch/utils/encryption_helper.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart' as dio;
import 'package:agora_chat_sdk/agora_chat_sdk.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _chatRepository = ChatRepository();
  final SocketService _socketService = SocketService();

  List<ConversationModel> _conversations = [];
  List<MessageModel> _messages = [];
  List<MessageModel> _pinnedMessages = [];
  List<PartnerModel> _searchedUsers = [];
  bool _isLoading = false;
  bool _isMessagesLoading = false;
  String? _error;
  PaginationModel? _pagination;
  UserStatus? _currentUserStatus;
  Set<String> _blockedUserIds = {};
  Set<String> _blockedByPartnerIds = {};
  Set<String> _mutedConversationIds = {};
  String? _activeConversationId;
  String? _activePartnerId;
  MessageModel? _replyingToMessage;
  String _inboxSearchQuery = '';
  final Set<String> _processedMessageIds = {};
  final Set<String> _processingFingerprints = {};


  // E2EE state
  KeyPair? _myKeyPair;
  final Map<String, PublicKey> _partnerPublicKeys = {};
  final Map<String, SecretKey> _sharedSecrets = {};
  final Map<String, SecretKey> _legacySharedSecrets = {};
  bool _isPublicKeySyncing = false;
  bool _publicKeySavedOnServer = false;

  // Agora Chat SDK state
  bool _isAgoraInitialized = false;
  bool _isAgoraLoggedIn = false;
  String? _agoraAppKey;
  String? _agoraUserId;
  String? _agoraToken;
  int? _agoraTokenExpiresAt;



  List<ConversationModel> get conversations => _conversations;
  List<ConversationModel> get filteredConversations {
    if (_inboxSearchQuery.isEmpty) return _conversations;
    final query = _inboxSearchQuery.toLowerCase();
    return _conversations.where((conv) {
      final name = conv.partner?.name?.toLowerCase() ?? '';
      final username = conv.partner?.username?.toLowerCase() ?? '';
      return name.contains(query) || username.contains(query);
    }).toList();
  }
  List<MessageModel> get messages => _messages;
  List<MessageModel> get pinnedMessages => _pinnedMessages;
  List<PartnerModel> get searchedUsers => _searchedUsers;
  bool get isLoading => _isLoading;
  bool get isMessagesLoading => _isMessagesLoading;
  String? get error => _error;
  PaginationModel? get pagination => _pagination;
  UserStatus? get currentUserStatus => _currentUserStatus;
  Set<String> get blockedUserIds => _blockedUserIds;
  Set<String> get blockedByPartnerIds => _blockedByPartnerIds;
  Set<String> get mutedConversationIds => _mutedConversationIds;
  MessageModel? get replyingToMessage => _replyingToMessage;

  bool isUserBlocked(String userId) => _blockedUserIds.contains(userId) || _blockedByPartnerIds.contains(userId);
  bool isBlockedByMe(String userId) => _blockedUserIds.contains(userId);
  bool isPartnerBlockedMe(String userId) => _blockedByPartnerIds.contains(userId);
  bool isMuted(String conversationId) => _mutedConversationIds.contains(conversationId);

  void toggleMute(String conversationId) {
    if (_mutedConversationIds.contains(conversationId)) {
      _mutedConversationIds.remove(conversationId);
    } else {
      _mutedConversationIds.add(conversationId);
    }
    notifyListeners();
  }

  void setReplyingMessage(MessageModel? message) {
    _replyingToMessage = message;
    notifyListeners();
  }

  void clearReplyingMessage() {
    _replyingToMessage = null;
    notifyListeners();
  }

  void setInboxSearchQuery(String query) {
    _inboxSearchQuery = query;
    notifyListeners();
  }

  ChatProvider() {
    _initSocket();
    _initNotificationListener();
    initE2EE();
    initAgoraChat();
  }

  Future<void> initAgoraChat() async {
    try {
      debugPrint('🚀 Agora: Starting initialization...');
      final response = await _chatRepository.getAgoraToken();
      
      if (response['success'] == true) {
        final data = response['data'];
        _agoraAppKey = data['appKey'];
        _agoraUserId = data['userId'];
        _agoraToken = data['token'];
        _agoraTokenExpiresAt = data['expiresAt'];

        if (_agoraAppKey != null) {
          ChatOptions options = ChatOptions(
            appKey: _agoraAppKey!,
            autoLogin: false,
          );
          await ChatClient.getInstance.init(options);
          _isAgoraInitialized = true;
          debugPrint('✅ Agora: SDK initialized successfully');
          
          await loginToAgora();
        }
      }
    } catch (e) {
      debugPrint('❌ Agora Init Error: $e');
    }
  }

  Future<void> loginToAgora() async {
    if (!_isAgoraInitialized || _agoraUserId == null || _agoraToken == null) return;
    
    try {
      debugPrint('🚀 Agora: Attempting login for $_agoraUserId...');
      await ChatClient.getInstance.loginWithAgoraToken(_agoraUserId!, _agoraToken!);
      _isAgoraLoggedIn = true;
      debugPrint('✅ Agora: Login successful');
    } on ChatError catch (e) {
      debugPrint('❌ Agora Login Failed: ${e.description}');
      // Handle special case for already logged in (200 is success in some SDK versions, but let's check Agora docs or common errors)
      // In Agora Chat SDK, if already logged in, it might throw an error or just work.
    }
  }

  Future<void> renewAgoraToken() async {
    try {
      final response = await _chatRepository.getAgoraToken();
      if (response['success'] == true) {
        final data = response['data'];
        _agoraToken = data['token'];
        _agoraTokenExpiresAt = data['expiresAt'];
        
        if (_agoraToken != null) {
          await ChatClient.getInstance.renewAgoraToken(_agoraToken!);
          debugPrint('✅ Agora: Token renewed successfully');
        }
      }
    } catch (e) {
      debugPrint('❌ Agora Token Renewal Failed: $e');
    }
  }

  Future<void> initE2EE() async {
    debugPrint('🚀 E2EE: Starting initialization...');
    
    // CRITICAL: Clear all E2EE caches on re-init.
    // This ensures that we re-derive secrets using the fixed EncryptionHelper
    // and don't use any "tweaked" secrets stored in memory.
    _partnerPublicKeys.clear();
    _sharedSecrets.clear();
    _legacySharedSecrets.clear();
    
    // Ensure Device ID exists
    if (HiveService.getDeviceId() == null) {
      final newDeviceId = 'dev_flutter_${Platform.isAndroid ? 'android' : 'ios'}_${const Uuid().v4().substring(0, 8)}';
      await HiveService.saveDeviceId(newDeviceId);
      debugPrint('E2EE: Generated new Device ID: $newDeviceId');
    }

    try {
      final privateKeyBytes = HiveService.getPrivateKey();
      final savedJwk = HiveService.getPublicKey();
      
      if (privateKeyBytes != null && savedJwk != null) {
        debugPrint('E2EE: Found saved keys. Loading...');
        debugPrint('E2EE: Saved JWK: $savedJwk');
        
        _myKeyPair = await EncryptionHelper.loadKeyPair(privateKeyBytes, savedJwk);
        final myPublicKey = await _myKeyPair!.extractPublicKey();
        debugPrint('E2EE: Loaded key type: ${myPublicKey.type.name}');

        // MIGRATION CHECK: Ensure we are on P-256
        if (myPublicKey.type != KeyPairType.p256 || savedJwk.contains('"X25519"') || savedJwk.contains('"OKP"')) {
          debugPrint('E2EE: Non P-256 keys detected. Migrating to P-256...');
          _myKeyPair = await EncryptionHelper.generateKeyPair();
          final keyPairData = await _myKeyPair!.extract();
          if (keyPairData is SimpleKeyPairData) {
            await HiveService.savePrivateKey(keyPairData.bytes);
          } else if (keyPairData is EcKeyPairData) {
            await HiveService.savePrivateKey(keyPairData.d);
          }
          final jwk = await EncryptionHelper.exportPublicKey(_myKeyPair!);
          await HiveService.savePublicKey(jwk);
          
          // Force immediate sync after migration
          await syncPublicKey();
        }
        debugPrint('E2EE: KeyPair loaded/migrated successfully');
      } else {
        debugPrint('E2EE: No saved keys found. Generating new KeyPair...');
        _myKeyPair = await EncryptionHelper.generateKeyPair();
        
        debugPrint('E2EE: Extracting KeyPair data...');
        final keyPairData = await _myKeyPair!.extract();
        
        if (keyPairData is SimpleKeyPairData) {
           await HiveService.savePrivateKey(keyPairData.bytes);
        } else if (keyPairData is EcKeyPairData) {
           await HiveService.savePrivateKey(keyPairData.d);
        }
        
        final jwk = await EncryptionHelper.exportPublicKey(_myKeyPair!);
        await HiveService.savePublicKey(jwk);
        
        debugPrint('E2EE: New KeyPair generated and saved locally');
      }

      // Always re-export and save to ensure latest JWK format
      final currentJwk = await EncryptionHelper.exportPublicKey(_myKeyPair!);
      await HiveService.savePublicKey(currentJwk);
      debugPrint('🔑 CURRENT PUBLIC KEY: $currentJwk');

      // Now send to server
      await syncPublicKey();
    } catch (e) {
      debugPrint('❌ E2EE Initialization Error: $e');
    }
  }

  Future<void> syncPublicKey() async {
    if (_isPublicKeySyncing) return;
    
    if (_myKeyPair == null) {
      debugPrint('⚠️ E2EE Sync: KeyPair is missing. Cannot send public key.');
      return;
    }
    
    final token = HiveService.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ E2EE Sync: User token is missing. Please login first.');
      return;
    }

    _isPublicKeySyncing = true;
    try {
      final jwkString = await EncryptionHelper.exportPublicKey(_myKeyPair!);
      
      debugPrint('📡 API CALL: POST /api/chat/keys');
      debugPrint('📡 Request Body: {"publicKey": "$jwkString"}');

      final response = await _chatRepository.savePublicKey(jwkString);
      
      if (response['success'] == true) {
        _publicKeySavedOnServer = true;
        debugPrint('✅ SUCCESS: Public key sent to server successfully');
      } else {
        debugPrint('❌ FAILED: Server rejected public key: ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ ERROR during API call /api/chat/keys: $e');
    } finally {
      _isPublicKeySyncing = false;
    }
  }

  Future<void> checkServerSyncStatus() async {
    if (_myKeyPair == null) {
      debugPrint('E2EE Sync Check: KeyPair not ready. Postponing check.');
      return;
    }

    try {
      debugPrint('E2EE Sync Check: Verifying public key status on server...');
      final response = await _chatRepository.getMyProfile();
      if (response['success'] == true) {
        final serverKey = response['user']['publicKey'];
        if (serverKey == null || serverKey.isEmpty) {
          debugPrint('E2EE Sync Check: Public key MISSING on server. Triggering sync...');
          _publicKeySavedOnServer = false;
          await syncPublicKey();
        } else {
          _publicKeySavedOnServer = true;
          debugPrint('E2EE Sync Check: Public key ALREADY present on server');
        }
      }
    } catch (e) {
      debugPrint('❌ E2EE Sync Check ERROR: $e');
    }
  }

  Future<SecretKey?> _getSharedSecret(String partnerId, {dynamic providedPublicKeyJwk, bool forceFetch = false}) async {
    debugPrint('E2EE: Attempting to get shared secret for partnerId: $partnerId (forceFetch: $forceFetch)');

    if (_myKeyPair == null) {
      debugPrint('E2EE ERROR: _myKeyPair is NULL in _getSharedSecret. User might not be initialized.');
      return null;
    }
    
    // Check if the provided key is different from what we have cached
    if (providedPublicKeyJwk != null) {
      final currentJwk = HiveService.getPartnerPublicKey(partnerId);
      final newJwkString = providedPublicKeyJwk is String ? providedPublicKeyJwk : jsonEncode(providedPublicKeyJwk);
      
      if (currentJwk != newJwkString) {
        debugPrint('E2EE: NEW Public Key detected for $partnerId. Invalidating secrets...');
        _partnerPublicKeys.remove(partnerId);
        _sharedSecrets.remove(partnerId);
        _legacySharedSecrets.remove(partnerId);
        await HiveService.savePartnerPublicKey(partnerId, newJwkString);
      }
    }

    if (!forceFetch && _sharedSecrets.containsKey(partnerId)) {
      debugPrint('E2EE: Returning cached secret for $partnerId');
      return _sharedSecrets[partnerId];
    }

    try {
      PublicKey? partnerPublicKey;
      
      if (_partnerPublicKeys.containsKey(partnerId)) {
        partnerPublicKey = _partnerPublicKeys[partnerId];
        debugPrint('E2EE: Using cached public key for $partnerId');
      }

      if (partnerPublicKey == null) {
        dynamic partnerPublicKeyJwk = providedPublicKeyJwk;
        
        // 1. Check persistent storage
        if (!forceFetch && partnerPublicKeyJwk == null) {
          partnerPublicKeyJwk = HiveService.getPartnerPublicKey(partnerId);
          if (partnerPublicKeyJwk != null) {
            debugPrint('E2EE: Found public key in Hive storage for $partnerId');
          }
        }

        // 2. Check conversations list with deep search
        if (partnerPublicKeyJwk == null) {
          debugPrint('E2EE: Searching for partner $partnerId in ${_conversations.length} conversations...');
          for (var conv in _conversations) {
            final p = conv.partner;
            if (p != null) {
              final pSid = p.sId?.toString();
              final pId = p.id?.toString();
              
              if ((pSid != null && pSid == partnerId) || (pId != null && pId == partnerId)) {
                if (p.publicKey != null) {
                  debugPrint('E2EE: Found public key in conversation metadata for partner $partnerId');
                  partnerPublicKeyJwk = p.publicKey;
                  break;
                }
              }
            }
          }
        }

        // 3. Fallback to API
        if (partnerPublicKeyJwk == null) {
          debugPrint('E2EE: Public key not in cache/metadata. Fetching from API for partner: $partnerId');
          final response = await _chatRepository.getUserPublicKey(partnerId);
          if (response['success'] == true) {
            // Flexible parsing of API response
            final data = response['data'] ?? response['user'] ?? response;
            partnerPublicKeyJwk = data is Map ? data['publicKey'] : null;
            
            if (partnerPublicKeyJwk != null) {
              debugPrint('E2EE: API returned public key for $partnerId');
            } else {
              debugPrint('E2EE ERROR: API response success but publicKey not found in: $data');
            }
          } else {
            debugPrint('E2EE: API failed to return public key for $partnerId. Error: ${response['message']}');
          }
        }

        if (partnerPublicKeyJwk != null) {
          debugPrint('E2EE: Importing partner public key for $partnerId. JWK type: ${partnerPublicKeyJwk.runtimeType}');
          partnerPublicKey = await EncryptionHelper.importPublicKey(partnerPublicKeyJwk);
          _partnerPublicKeys[partnerId] = partnerPublicKey;
          
          // Persist it
          final jwkString = partnerPublicKeyJwk is String ? partnerPublicKeyJwk : jsonEncode(partnerPublicKeyJwk);
          await HiveService.savePartnerPublicKey(partnerId, jwkString);
        } else {
          debugPrint('E2EE WARNING: Failed to obtain any public key for $partnerId. The user may not have E2EE set up.');
        }
      }

      if (partnerPublicKey != null) {
        debugPrint('E2EE: Deriving shared secret with EncryptionHelper...');
        final secret = await EncryptionHelper.deriveSharedSecret(_myKeyPair!, partnerPublicKey);
        _sharedSecrets[partnerId] = secret;
        debugPrint('E2EE: Shared secret derived successfully for $partnerId');
        return secret;
      }
    } catch (e, stack) {
      debugPrint('E2EE Error deriving shared secret for $partnerId: $e');
      debugPrint('E2EE Stacktrace: $stack');
    }
    return null;
  }

  Future<SecretKey?> _getLegacySharedSecret(String partnerId) async {
    if (_myKeyPair == null) return null;
    if (_legacySharedSecrets.containsKey(partnerId)) return _legacySharedSecrets[partnerId];

    try {
      PublicKey? partnerPublicKey = _partnerPublicKeys[partnerId];
      if (partnerPublicKey == null) {
        // We usually have it in cache if we reached here, but try to fetch if not
        await _getSharedSecret(partnerId);
        partnerPublicKey = _partnerPublicKeys[partnerId];
      }

      if (partnerPublicKey != null) {
        debugPrint('E2EE: Deriving LEGACY shared secret for $partnerId...');
        final secret = await EncryptionHelper.deriveSharedSecretLegacy(_myKeyPair!, partnerPublicKey);
        _legacySharedSecrets[partnerId] = secret;
        return secret;
      }
    } catch (e) {
      debugPrint('E2EE Error deriving legacy secret for $partnerId: $e');
    }
    return null;
  }

  void initSocket() {
    checkServerSyncStatus(); // Check sync status when starting socket
    _socketService.disconnect();
    _socketService.connect();
  }



  void _initSocket() {
    _socketService.connect();
    _socketService.messageStream.listen((data) {
      debugPrint('Socket Event Received: ${data['event']}');
      _handleSocketMessage(data);
    }, onError: (e) {
      debugPrint('Socket Stream Error: $e');
    });
  }

  void _initNotificationListener() {
    NotificationService.foregroundMessageStream.listen((message) {
      debugPrint('FCM Foreground Message Received in ChatProvider');
      _handleForegroundNotification(message);
    });
  }

  void _handleForegroundNotification(RemoteMessage message) {
    try {
      final type = message.data['type'];
      final conversationId = message.data['conversationId'];
      
      if (type == 'CHAT_MESSAGE' || conversationId != null) {
        debugPrint('Processing foreground notification: Type=$type, Conv=$conversationId');

        if (!_socketService.isConnected) {
          if (type == 'READ_RECEIPT' || type == 'MESSAGE_READ') {
            _onMessageRead(message.data);
          } else if (type == 'DELIVERED_RECEIPT' || type == 'MESSAGE_DELIVERED') {
            _onMessageDelivered(message.data);
          } else {
            // New message fallback
            final Map<String, dynamic> payload = Map<String, dynamic>.from(message.data);
            if (payload['text'] == null && payload['body'] == null && payload['message'] == null) {
              if (message.notification != null) {
                payload['text'] = message.notification!.body;
              }
            }
            _onNewMessage(payload);
          }
          
          // Try to reconnect
          _socketService.connect();
        }
      }
    } catch (e) {
      debugPrint('Error handling foreground notification in ChatProvider: $e');
    }
  }

  void _handleSocketMessage(Map<String, dynamic> data) {
    final event = data['event'];
    final payload = data['data'];

    switch (event) {
      case 'new_message':
      case 'receive_message':
      case 'message':
        _onNewMessage(payload);
        break;
      case 'status_update':
      case 'user_status':
        _onStatusUpdate(payload);
        break;
      case 'message_read':
      case 'read_receipt':
      case 'READ_RECEIPT':
        _onMessageRead(payload);
        break;
      case 'message_delivered':
      case 'delivered_receipt':
      case 'DELIVERED_RECEIPT':
        _onMessageDelivered(payload);
        break;
      case 'user_blocked':
        _onUserBlocked(payload);
        break;
      case 'message_reaction':
      case 'new_reaction':
      case 'reaction':
        _onMessageReaction(payload);
        break;
      case 'message_edited':
      case 'edit_message':
        _onMessageEdited(payload);
        break;
      case 'incoming_call':
      case 'call_accepted':
      case 'call_rejected':
      case 'call_ended':
      case 'call_cancelled':
      case 'call_busy':
      case 'call_missed':
        // Handled by CallProvider
        break;
      default:
        debugPrint('Unhandled Socket Event: $event');
    }
  }

  void _onNewMessage(dynamic payload) async {
    try {
      debugPrint('Processing New Message Payload: $payload');
      final MessageModel newMessage;
      
      if (payload is Map<String, dynamic> && payload.containsKey('_id')) {
        newMessage = MessageModel.fromJson(payload);
      } else {
        // Handle flat map from FCM (Map<String, String>)
        // ... (rest of existing code)
        dynamic senderData = payload['sender'];
        if (senderData is String && senderData.startsWith('{')) {
          try {
            senderData = jsonDecode(senderData);
          } catch (_) {}
        }

        newMessage = MessageModel(
          sId: payload['_id'] ?? payload['messageId'] ?? payload['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: payload['conversationId'],
          text: payload['text'] ?? payload['body'] ?? payload['message'] ?? '',
          messageType: payload['messageType'] ?? 'text',
          mediaUrl: payload['mediaUrl'],
          createdAt: payload['createdAt'] ?? DateTime.now().toIso8601String(),
          sender: senderData is Map 
            ? Sender.fromJson(Map<String, dynamic>.from(senderData))
            : Sender(
                sId: payload['senderId'] ?? payload['sender_id'],
                name: payload['senderName'] ?? payload['sender_name'],
                profileImage: payload['senderImage'] ?? payload['sender_image'],
              ),
          status: 'DELIVERED',
          isEncrypted: payload['isEncrypted'] == true || payload['isEncrypted'] == 'true',
          iv: payload['iv'],
        );
      }

      // CRITICAL: Deduplicate immediately using sId
      if (newMessage.sId != null) {
        if (_processedMessageIds.contains(newMessage.sId)) {
          debugPrint('Duplicate message detected by sId: ${newMessage.sId}');
          return;
        }
        _processedMessageIds.add(newMessage.sId!);
        
        // Keep the set size manageable
        if (_processedMessageIds.length > 500) {
          _processedMessageIds.remove(_processedMessageIds.first);
        }
      }

      // CRITICAL: Content-based deduplication for call events that might have different IDs
      if (newMessage.messageType == 'call' || newMessage.messageType == 'audio_call' || newMessage.messageType == 'video_call') {
        final String fingerprint = '${newMessage.conversationId}_${newMessage.messageType}_${newMessage.sender?.sId}';
        
        if (_processingFingerprints.contains(fingerprint)) {
          debugPrint('Duplicate call event detected by simultaneous processing fingerprint');
          return;
        }

        final bool alreadyExists = _messages.take(10).any((m) {
          return m.messageType == newMessage.messageType && 
                 m.conversationId == newMessage.conversationId &&
                 m.sender?.sId == newMessage.sender?.sId &&
                 DateTime.now().difference(DateTime.tryParse(m.createdAt ?? '') ?? DateTime.now()).inSeconds.abs() < 5;
        });
        
        if (alreadyExists) {
          debugPrint('Duplicate call event detected by existing message content');
          return;
        }

        _processingFingerprints.add(fingerprint);
        // Remove from processing set after a short delay (enough for the message to be inserted into _messages)
        Future.delayed(const Duration(seconds: 5), () {
          _processingFingerprints.remove(fingerprint);
        });
      }

      // Decrypt message if it's text
      if ((newMessage.isEncrypted == true || newMessage.messageType == 'text') && newMessage.text != null && newMessage.text!.isNotEmpty) {
        final senderId = newMessage.sender?.sId ?? newMessage.sender?.id;
        if (senderId != null && senderId != HiveService.userId) {
          await _decryptMessagesList([newMessage], senderId);
        }
      }


      final conversationId = newMessage.conversationId;

      debugPrint('Resolved Message: ID=${newMessage.sId}, Text=${newMessage.text}, Conv=${newMessage.conversationId}');
      
      if (conversationId == null) {
        debugPrint('Warning: New message has no conversationId');
        return;
      }

      // Update current message list if it's the active conversation
      if (conversationId == _activeConversationId) {
        debugPrint('Updating active conversation messages list');
        
        // Final deduplication before inserting into active list
        bool alreadyExists = _messages.any((m) => m.sId == newMessage.sId);
        
        if (!alreadyExists) {
          _messages.insert(0, newMessage);
          debugPrint('Message inserted into list');
          
          // Vibrate for new message in active chat (short)
          Vibration.vibrate(duration: 50);
        } else {
          debugPrint('Message already exists in list, skipping insertion');
        }
      } else {
        debugPrint('Message is not for active conversation, skipping list update');
        // Vibrate for new message in background (slightly longer or pattern)
        Vibration.vibrate(duration: 100);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling new message socket event: $e');
    }
  }

  void _onStatusUpdate(dynamic payload) {
    try {
      final status = UserStatus.fromJson(payload);
      
      // Update partner status in conversations list
      bool changed = false;
      for (var conv in _conversations) {
        if (conv.partner?.sId == status.userId || conv.partner?.id == status.userId) {
          conv.partner?.isOnline = status.isOnline;
          conv.partner?.lastSeen = status.lastSeen;
          changed = true;
        }
      }

      if (_currentUserStatus?.userId == status.userId) {
        _currentUserStatus = status;
        changed = true;
      }
      
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('Error handling status update socket event: $e');
    }
  }

  void _onMessageRead(dynamic payload) {
    try {
      final conversationId = payload['conversationId'] ?? payload['conversation_id'];
      debugPrint('Message Read Event for Conversation: $conversationId (Active: $_activeConversationId)');
      
      if (conversationId == null) return;

      // Update in conversation list
      final convIndex = _conversations.indexWhere((c) => c.sId == conversationId);
      if (convIndex != -1) {
        _conversations[convIndex].unreadCount = 0;
        if (_conversations[convIndex].lastMessage != null) {
          _conversations[convIndex].lastMessage!.status = 'READ';
        }
      }

      if (conversationId == _activeConversationId) {
        debugPrint('Marking local messages as READ');
        bool changed = false;
        for (var msg in _messages) {
          // If we receive a read receipt for the conversation, all previous messages are read
          if (msg.status != 'READ') {
            msg.status = 'READ';
            changed = true;
          }
        }
        if (changed) notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling message read event: $e');
    }
  }

  void _onMessageDelivered(dynamic payload) {
    try {
      final conversationId = payload['conversationId'] ?? payload['conversation_id'];
      final messageId = payload['messageId'] ?? payload['message_id'] ?? payload['_id'];
      
      debugPrint('Message Delivered Event for Conversation: $conversationId, Message: $messageId');

      if (conversationId == null) return;

      if (conversationId == _activeConversationId) {
        bool changed = false;
        if (messageId != null) {
          final index = _messages.indexWhere((m) => m.sId == messageId);
          if (index != -1 && _messages[index].status != 'READ') {
            _messages[index].status = 'DELIVERED';
            changed = true;
          }
        } else {
          // If no specific message ID, mark all 'SENT' as 'DELIVERED'
          for (var msg in _messages) {
            if (msg.status == 'SENT' || msg.status == null) {
              msg.status = 'DELIVERED';
              changed = true;
            }
          }
        }
        if (changed) notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling message delivered event: $e');
    }
  }

  void _onMessageReaction(dynamic payload) {
    try {
      final messageId = payload['messageId'];
      final reaction = ReactionModel.fromJson(payload['reaction'] ?? payload);
      
      final index = _messages.indexWhere((m) => m.sId == messageId);
      if (index != -1) {
        final reactions = _messages[index].reactions ?? [];
        // Remove old reaction from same user if exists
        reactions.removeWhere((r) => r.userId == reaction.userId);
        reactions.add(reaction);
        _messages[index].reactions = reactions;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling message reaction socket event: $e');
    }
  }

  void _onMessageEdited(dynamic payload) async {
    try {
      debugPrint('E2EE: Handling message_edited socket event: $payload');
      final messageId = payload['messageId'] ?? payload['_id'];
      final conversationId = payload['conversationId'];
      final newText = payload['text'] ?? payload['message'] ?? payload['body'];
      final isEncrypted = payload['isEncrypted'] == true || payload['isEncrypted'] == 'true';
      final iv = payload['iv'];
      
      // Robust senderId detection
      var senderId = payload['senderId'];
      if (senderId == null && payload['sender'] != null) {
        if (payload['sender'] is Map) {
          senderId = payload['sender']['_id'] ?? payload['sender']['id'];
        } else {
          senderId = payload['sender'].toString();
        }
      }

      if (messageId == null) return;

      // Find the message in local history
      final index = _messages.indexWhere((m) => m.sId == messageId);
      final existingMsg = index != -1 ? _messages[index] : null;

      // IGNORE MY OWN EDITS for text overwrite, but update metadata
      final bool isMe = (senderId != null && senderId == HiveService.userId) || 
                       (existingMsg != null && (existingMsg.sender?.sId == HiveService.userId || existingMsg.sender?.id == HiveService.userId));

      if (isMe) {
        debugPrint('E2EE: Ignoring broadcast of my own edit text to preserve plain text');
        if (existingMsg != null) {
          existingMsg.isEncrypted = isEncrypted;
          existingMsg.iv = iv;
          existingMsg.isEdited = true;
        }
      } else {
        if (existingMsg != null) {
          existingMsg.text = newText;
          existingMsg.isEncrypted = isEncrypted;
          existingMsg.iv = iv;
          existingMsg.isEdited = true;
          existingMsg.isDecrypted = false;

          // Find partnerId for decryption
          final conv = _conversations.firstWhere((c) => c.sId == conversationId, orElse: () => ConversationModel());
          final partnerId = senderId ?? conv.partner?.sId ?? conv.partner?.id ?? _activePartnerId;

          if (isEncrypted && newText != null && partnerId != null) {
            await _decryptMessagesList([existingMsg], partnerId);
          } else {
            existingMsg.isDecrypted = true;
          }
        }
      }

      // Update in conversation list preview (Inbox) - ALWAYS do this even if isMe
      final convIndex = _conversations.indexWhere((c) => c.sId == conversationId);
      if (convIndex != -1) {
        final lastMsg = _conversations[convIndex].lastMessage;
        if (lastMsg?.sId == messageId) {
          if (!isMe) {
            lastMsg!.text = newText;
            lastMsg.isEncrypted = isEncrypted;
            lastMsg.iv = iv;
            lastMsg.isDecrypted = false;
            
            final partnerId = senderId ?? _conversations[convIndex].partner?.sId ?? _conversations[convIndex].partner?.id;
            if (isEncrypted && newText != null && partnerId != null) {
              await _decryptMessagesList([lastMsg], partnerId);
            } else {
              lastMsg.isDecrypted = true;
            }
          } else {
            // If it's me, ensure the last message in inbox matches the edited text
            // existingMsg might have the plain text updated from editMessage()
            if (existingMsg != null) {
              lastMsg!.text = existingMsg.text;
              lastMsg.isDecrypted = true;
            }
          }
        }
        _conversations[convIndex].lastMessageAt = DateTime.now().toIso8601String(); // Ensure it stays at top
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling message edited socket event: $e');
    }
  }

  void _onUserBlocked(dynamic payload) {
    final blockedId = payload['blockedId'] ?? payload['blockedUserId'];
    final blockerId = payload['blockerId'];
    final currentUserId = HiveService.userId;

    if (blockerId == currentUserId) {
      _blockedUserIds.add(blockedId);
    } else if (blockedId == currentUserId) {
      // Current user was blocked by someone
      _blockedByPartnerIds.add(blockerId);
    }
    notifyListeners();
  }

  void setActiveConversation(String? id, [String? partnerId]) {
    _activeConversationId = id;
    _activePartnerId = partnerId;
    NotificationService.activeChatId = id;
    if (id != null) {
      markAsRead(id);
    }
  }


  int get totalUnreadCount {
    int count = 0;
    for (var conv in _conversations) {
      count += conv.unreadCount ?? 0;
    }
    return count;
  }

  Future<void> fetchConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Ensure socket is connected when we start interacting with chat
    _socketService.connect();
    
    // Check key sync status
    if (!_publicKeySavedOnServer) {
      checkServerSyncStatus();
    }


    try {

      final response = await _chatRepository.fetchConversations();
      _conversations = response;

      // Sync block status and cache public keys from conversation data
      for (var conv in _conversations) {
        final partnerId = conv.partner?.sId ?? conv.partner?.id;
        if (partnerId != null) {
          // Cache Public Key if present
          if (conv.partner?.publicKey != null) {
            try {
              final newJwk = conv.partner!.publicKey is String ? conv.partner!.publicKey : jsonEncode(conv.partner!.publicKey);
              final oldJwk = HiveService.getPartnerPublicKey(partnerId);
              
              if (newJwk != oldJwk) {
                debugPrint('E2EE: Detected updated public key in conversation list for $partnerId. Updating cache...');
                await HiveService.savePartnerPublicKey(partnerId, newJwk);
                _partnerPublicKeys.remove(partnerId);
                _sharedSecrets.remove(partnerId);
                _legacySharedSecrets.remove(partnerId);
              }

              if (!_partnerPublicKeys.containsKey(partnerId)) {
                final partnerPublicKey = await EncryptionHelper.importPublicKey(conv.partner!.publicKey);
                _partnerPublicKeys[partnerId] = partnerPublicKey;
                debugPrint('E2EE: Cached public key for partner $partnerId from conversation list');
              }
            } catch (e) {
              debugPrint('E2EE Error caching key for $partnerId: $e');
            }
          }

          if (conv.isBlockedByMe == true) {
            _blockedUserIds.add(partnerId);
          } else {
            _blockedUserIds.remove(partnerId);
          }
          
          if (conv.isBlockedByPartner == true) {
            _blockedByPartnerIds.add(partnerId);
          } else {
            _blockedByPartnerIds.remove(partnerId);
          }

          // Decrypt last message preview
          if (conv.lastMessage != null) {
            await _decryptMessagesList([conv.lastMessage!], partnerId);
          }
        }
      }

      // Sort: pinned first, then by last message time
      _sortConversations();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      if (a.isPinned == true && b.isPinned != true) return -1;
      if (a.isPinned != true && b.isPinned == true) return 1;
      
      DateTime timeA = DateTime.tryParse(a.lastMessageAt ?? '') ?? DateTime(2000);
      DateTime timeB = DateTime.tryParse(b.lastMessageAt ?? '') ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _chatRepository.markAsRead(conversationId);
      final index = _conversations.indexWhere((c) => c.sId == conversationId);
      if (index != -1) {
        _conversations[index].unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> togglePin(String conversationId) async {
    try {
      debugPrint('Toggling pin for: $conversationId');
      final response = await _chatRepository.togglePin(conversationId);
      debugPrint('Toggle pin response: $response');
      
      final index = _conversations.indexWhere((c) => c.sId == conversationId);
      if (index != -1) {
        _conversations[index].isPinned = !(_conversations[index].isPinned ?? false);
        _sortConversations();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  Future<bool> clearChat(String conversationId) async {
    try {
      await _chatRepository.clearChat(conversationId);
      _conversations.removeWhere((c) => c.sId == conversationId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing chat: $e');
      return false;
    }
  }

  Future<String?> createConversation(String recipientId) async {
    try {
      final response = await _chatRepository.createConversation(recipientId);
      if (response['success'] == true) {
        await fetchConversations();
        return response['data']['_id'] ?? response['data']['id'];
      }
      return null;
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      return null;
    }
  }

  // Message Methods
  Future<void> fetchMessages(String conversationId, {int page = 1}) async {
    // Ensure socket is connected when we enter a conversation
    _socketService.connect();

    if (page == 1) {
      _messages = [];
      _isMessagesLoading = true;
      _pagination = null;
      notifyListeners();
    }

    try {
      final response = await _chatRepository.fetchMessages(conversationId, page: page);
      _pagination = response.pagination;
      
      // Reverse the list because API returns Oldest First, but we want Newest at index 0 for reverse ListView
      final List<MessageModel> newMessages = (response.data ?? []).reversed.toList();
      
      // Decrypt messages
      final partnerId = _activePartnerId ?? _conversations.firstWhere((c) => c.sId == conversationId, orElse: () => ConversationModel()).partner?.sId;
      if (partnerId != null) {
        await _decryptMessagesList(newMessages, partnerId);
      }

      if (page == 1) {
        _messages = newMessages;
      } else {
        _messages.addAll(newMessages);
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching messages for $conversationId: $e');
      debugPrint('Stacktrace: $stackTrace');
    } finally {
      _isMessagesLoading = false;
      notifyListeners();
    }
  }

  Future<void> _decryptMessagesList(List<MessageModel> messages, String partnerId) async {
    debugPrint('E2EE: Decrypting ${messages.length} messages for partner $partnerId. Deriving secret...');
    SecretKey? secret = await _getSharedSecret(partnerId);
    
    if (secret == null) {
      debugPrint('E2EE: Could not obtain shared secret for $partnerId');
      return;
    }

    SecretKey? legacySecret = await _getLegacySharedSecret(partnerId);
    bool recovered = false;
    
    for (var msg in messages) {
      if (msg.messageType == 'text' && msg.text != null && msg.text!.isNotEmpty) {
        // If it's already decrypted, skip
        if (msg.isDecrypted) continue;
        
        msg.cipherText = msg.text;
        
        Future<void> attemptDecryption() async {
          // 1. Try Standard
          try {
            final decrypted = await EncryptionHelper.decrypt(msg.text!, secret!, iv: msg.iv);
            if (decrypted != msg.text) {
              msg.text = decrypted;
              msg.isDecrypted = true;
              return;
            }
          } catch (_) {}
          
          // 2. Try Legacy
          if (legacySecret != null) {
            try {
              final decrypted = await EncryptionHelper.decrypt(msg.text!, legacySecret!, iv: msg.iv);
              if (decrypted != msg.text) {
                msg.text = decrypted;
                msg.isDecrypted = true;
                return;
              }
            } catch (_) {}
          }

          // 3. Try Hashed
          try {
            final partnerKey = _partnerPublicKeys[partnerId];
            if (partnerKey != null) {
              final hashedSecret = await EncryptionHelper.deriveSharedSecretHashed(_myKeyPair!, partnerKey);
              final decrypted = await EncryptionHelper.decrypt(msg.text!, hashedSecret, iv: msg.iv);
              if (decrypted != msg.text) {
                msg.text = decrypted;
                msg.isDecrypted = true;
                return;
              }
            }
          } catch (_) {}
        }

        await attemptDecryption();

        // If still failed and we haven't tried recovery for this batch
        if (!msg.isDecrypted && !recovered) {
          debugPrint('E2EE: Decryption failed for message. Attempting cache recovery...');
          recovered = true;
          _partnerPublicKeys.remove(partnerId);
          _sharedSecrets.remove(partnerId);
          _legacySharedSecrets.remove(partnerId);
          await HiveService.deletePartnerPublicKey(partnerId);

          secret = await _getSharedSecret(partnerId, forceFetch: true);
          legacySecret = await _getLegacySharedSecret(partnerId);
          
          if (secret != null) {
            await attemptDecryption(); // Try one more time with fresh secret
          }
        }
      }
    }
    debugPrint('E2EE: Decryption complete. Decrypted: ${messages.where((m) => m.isDecrypted).length}');
  }

  Future<bool> sendMessage({
    required String conversationId,
    required String messageType,
    String? text,
    String? mediaUrl,
    String? replyTo,
  }) async {
    _error = null;
    try {
      // Find partner ID from conversation
      String? partnerId = _activePartnerId;
      if (partnerId == null) {
        final conv = _conversations.firstWhere((c) => c.sId == conversationId, orElse: () => ConversationModel());
        partnerId = conv.partner?.sId ?? conv.partner?.id;
      }

      String? encryptedText = text;
      String? iv;
      bool isEncrypted = false;
      if (messageType == 'text' && text != null && partnerId != null) {
        debugPrint('E2EE: Attempting to encrypt message for partnerId: $partnerId');
        
        if (_myKeyPair == null) {
          debugPrint('E2EE WARNING: My KeyPair is NULL. Attempting re-initialization...');
          await initE2EE();
        }

        // Ensure our own key is synced before encrypting (fail-safe)
        if (!_publicKeySavedOnServer) {
          debugPrint('E2EE: Public key not confirmed on server. Syncing now...');
          await syncPublicKey();
        }

        // PROACTIVE KEY LOOKUP: Try to find partner's public key in conversations list
        dynamic partnerKeyFromMeta;
        for (var conv in _conversations) {
          final p = conv.partner;
          if (p != null && ((p.sId == partnerId) || (p.id == partnerId))) {
            partnerKeyFromMeta = p.publicKey;
            if (partnerKeyFromMeta != null) {
              debugPrint('E2EE: Proactively found partner key in conversation metadata');
              break;
            }
          }
        }

        final secret = await _getSharedSecret(partnerId, providedPublicKeyJwk: partnerKeyFromMeta);

        if (secret != null) {
          debugPrint('E2EE: Shared secret obtained. Calling EncryptionHelper.encrypt...');
          final encryptionResult = await EncryptionHelper.encrypt(text, secret);
          
          final String? cipherText = encryptionResult['text'];
          final String? nonce = encryptionResult['iv'];
          
          debugPrint('E2EE: Encryption Result - cipherText isNull: ${cipherText == null}, iv isNullOrEmpty: ${nonce == null || nonce.isEmpty}');

          if (cipherText != null && cipherText != text && nonce != null && nonce.isNotEmpty) {
            encryptedText = cipherText;
            iv = nonce;
            isEncrypted = true;
            debugPrint('E2EE: Encryption successful. Final isEncrypted: $isEncrypted');
          } else {
            debugPrint('E2EE WARNING: Encryption helper output validation failed. Fallback to PLAIN TEXT.');
            debugPrint('E2EE DEBUG: textMatch: ${cipherText == text}, ivEmpty: ${nonce?.isEmpty}');
          }
        } else {
          debugPrint('E2EE WARNING: Failed to get shared secret for $partnerId. Encryption impossible. Fallback to PLAIN TEXT.');
        }
      }


      final actualReplyTo = replyTo ?? _replyingToMessage?.sId;

      final myPublicKeyJwk = HiveService.getPublicKey();
      final myDeviceId = HiveService.getDeviceId() ?? 'unknown_device';
      final myUserId = HiveService.userId ?? 'unknown_user';

      final Map<String, dynamic> data = {
        'conversationId': conversationId,
        'recipientId': partnerId,
        'isEncrypted': isEncrypted,
        'iv': iv ?? '',
        'messageType': messageType,
        'replyTo': actualReplyTo,
        'text': encryptedText ?? text ?? '', 
      };

      if (isEncrypted && encryptedText != null && iv != null) {
        data['encryption'] = {
          'version': 2,
          'senderDeviceId': myDeviceId,
          'senderKeyId': 'key_$myUserId',
          'senderPublicKey': myPublicKeyJwk,
          'recipientDeviceId': 'dev_${partnerId}_01',
          'recipientKeyId': 'key_$partnerId',
          'envelopes': [
            {
              'userId': partnerId,
              'deviceId': 'dev_${partnerId}_01',
              'keyId': 'key_$partnerId',
              'senderDeviceId': myDeviceId,
              'senderKeyId': 'key_$myUserId',
              'senderPublicKey': myPublicKeyJwk,
              'ciphertext': encryptedText,
              'iv': iv,
            }
          ]
        };
        data['ciphertext'] = encryptedText;
        data['senderPublicKey'] = myPublicKeyJwk;
      }

      final response = await _chatRepository.sendMessage(data);
      if (response['success'] == true) {
        clearReplyingMessage();
        
        // OPTIMISTIC UPDATE: Add message to local list instead of re-fetching
        // This prevents the "blink" caused by fetchMessages(conversationId)
        final sentMessage = MessageModel.fromJson(response['data']);
        
        // Decrypt for local display (it should be the plain text anyway, but good to be consistent)
        if (sentMessage.messageType == 'text') {
           sentMessage.text = text;
           sentMessage.isDecrypted = true;
        }

        if (conversationId == _activeConversationId) {
          if (!_messages.any((m) => m.sId == sentMessage.sId)) {
            _messages.insert(0, sentMessage);
          }
        }
        
        // Update conversation last message
        final convIndex = _conversations.indexWhere((c) => c.sId == conversationId);
        if (convIndex != -1) {
          _conversations[convIndex].lastMessage = sentMessage;
          _conversations[convIndex].lastMessageAt = sentMessage.createdAt;
          _sortConversations();
        }

        notifyListeners();
        return true;
      }
      return false;
    } on dio.DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _error = e.response?.data['message'] ?? "Cannot send message to blocked user";
        
        // Immediately update local blocked status to hide typing bar
        final conv = _conversations.firstWhere((c) => c.sId == conversationId, orElse: () => ConversationModel());
        if (conv.partner?.sId != null) {
          _blockedByPartnerIds.add(conv.partner!.sId!);
        } else if (conv.partner?.id != null) {
          _blockedByPartnerIds.add(conv.partner!.id!);
        }
      } else {
        _error = e.message;
      }
      debugPrint('Dio Error sending message: $e');
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error sending message: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> forwardMessage({
    required String recipientId,
    required MessageModel originalMessage,
  }) async {
    try {
      debugPrint('E2EE: Forwarding message to $recipientId');
      
      String? textToForward = originalMessage.text;
      String? iv;
      bool isEncrypted = false;
      
      // Ensure we have plain text to encrypt
      if (originalMessage.messageType == 'text' && textToForward != null) {
        final secret = await _getSharedSecret(recipientId);
        if (secret != null) {
          final encryptionResult = await EncryptionHelper.encrypt(textToForward, secret);
          textToForward = encryptionResult['text'];
          iv = encryptionResult['iv'];
          if (textToForward != originalMessage.text) {
            isEncrypted = true;
            debugPrint('E2EE: Message encrypted for forwarding');
          }
        }
      }

      final myPublicKeyJwk = HiveService.getPublicKey();
      final myDeviceId = HiveService.getDeviceId() ?? 'unknown_device';
      final myUserId = HiveService.userId ?? 'unknown_user';

      // Find if we already have a conversation with the recipient
      final existingConv = _conversations.firstWhere(
        (c) => c.partner?.sId == recipientId || c.partner?.id == recipientId,
        orElse: () => ConversationModel(),
      );

      final Map<String, dynamic> data = {
        'conversationId': existingConv.sId, // Use existing conversation if available
        'recipientId': recipientId,
        'isEncrypted': isEncrypted,
        'iv': iv ?? '',
        'mediaMeta': {},
        'mediaUrl': originalMessage.mediaUrl ?? '',
        'messageType': originalMessage.messageType ?? 'text',
        'replyTo': null,
        'text': textToForward ?? '',
        'isForwarded': true,
      };

      if (isEncrypted && textToForward != null && iv != null) {
        data['encryption'] = {
          'version': 2,
          'senderDeviceId': myDeviceId,
          'senderKeyId': 'key_$myUserId',
          'senderPublicKey': myPublicKeyJwk,
          'recipientDeviceId': 'dev_${recipientId}_01',
          'recipientKeyId': 'key_$recipientId',
          'envelopes': [
            {
              'userId': recipientId,
              'deviceId': 'dev_${recipientId}_01',
              'keyId': 'key_$recipientId',
              'senderDeviceId': myDeviceId,
              'senderKeyId': 'key_$myUserId',
              'senderPublicKey': myPublicKeyJwk,
              'ciphertext': textToForward,
              'iv': iv,
            }
          ]
        };
        data['ciphertext'] = textToForward;
        data['senderPublicKey'] = myPublicKeyJwk;
      }

      final response = await _chatRepository.sendMessage(data);

      if (response['success'] == true) {
        await fetchConversations();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error forwarding message: $e');
      return false;
    }
  }

  Future<void> editMessage(String conversationId, String messageId, String newText) async {
    try {
      final conv = _conversations.firstWhere((c) => c.sId == conversationId, orElse: () => ConversationModel());
      final partnerId = conv.partner?.sId ?? conv.partner?.id;
      
      // OPTIMISTIC UPDATE: Update UI instantly
      final index = _messages.indexWhere((m) => m.sId == messageId);
      if (index != -1) {
        _messages[index].text = newText;
        _messages[index].isEdited = true;
        _messages[index].isDecrypted = true;
        notifyListeners();
      }

      final convIndex = _conversations.indexWhere((c) => c.sId == conversationId);
      if (convIndex != -1 && _conversations[convIndex].lastMessage?.sId == messageId) {
        _conversations[convIndex].lastMessage!.text = newText;
        _conversations[convIndex].lastMessage!.isDecrypted = true;
        notifyListeners();
      }

      String encryptedText = newText;
      String? iv;
      bool isEncrypted = false;
      Map<String, dynamic>? encryptionMetadata;

      if (partnerId != null) {
        final secret = await _getSharedSecret(partnerId);
        if (secret != null) {
          final encryptionResult = await EncryptionHelper.encrypt(newText, secret);
          encryptedText = encryptionResult['text'] ?? newText;
          iv = encryptionResult['iv'];
          isEncrypted = encryptedText != newText;

          if (isEncrypted && iv != null) {
            final myPublicKeyJwk = HiveService.getPublicKey();
            final myDeviceId = HiveService.getDeviceId() ?? 'unknown_device';
            final myUserId = HiveService.userId ?? 'unknown_user';

            encryptionMetadata = {
              'version': 2,
              'senderDeviceId': myDeviceId,
              'senderKeyId': 'key_$myUserId',
              'senderPublicKey': myPublicKeyJwk,
              'recipientDeviceId': 'dev_${partnerId}_01',
              'recipientKeyId': 'key_$partnerId',
              'envelopes': [
                {
                  'userId': partnerId,
                  'deviceId': 'dev_${partnerId}_01',
                  'keyId': 'key_$partnerId',
                  'senderDeviceId': myDeviceId,
                  'senderKeyId': 'key_$myUserId',
                  'senderPublicKey': myPublicKeyJwk,
                  'ciphertext': encryptedText,
                  'iv': iv,
                }
              ]
            };
          }
        }
      }

      final response = await _chatRepository.editMessage(
        messageId, 
        encryptedText, 
        isEncrypted: isEncrypted, 
        iv: iv,
        encryption: encryptionMetadata,
      );

      if (response['success'] == true) {
        debugPrint('✅ Message edit API successful');
      } else {
        debugPrint('❌ Message edit API failed: ${response['message']}');
        // Optional: Revert optimistic update here if needed
      }

      // Final sync with metadata if needed, but text is already set
      if (index != -1) {
        _messages[index].isEncrypted = isEncrypted;
        _messages[index].iv = iv;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error editing message: $e');
    }
  }


  Future<void> unsendMessage(String conversationId, String messageId) async {
    try {
      await _chatRepository.unsendMessage(messageId);
      final index = _messages.indexWhere((m) => m.sId == messageId);
      if (index != -1) {
        _messages[index].isUnsent = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error unsending message: $e');
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _chatRepository.deleteMessage(messageId);
      _messages.removeWhere((m) => m.sId == messageId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    try {
      final currentUserId = HiveService.userId;
      
      // Update locally for immediate feedback
      final index = _messages.indexWhere((m) => m.sId == messageId);
      if (index != -1) {
        final reactions = _messages[index].reactions ?? [];
        // Remove existing reaction from this user
        reactions.removeWhere((r) => r.userId == currentUserId);
        // Add new reaction
        reactions.add(ReactionModel(userId: currentUserId, emoji: emoji));
        _messages[index].reactions = reactions;
        notifyListeners();
      }

      await _chatRepository.reactToMessage(messageId, emoji);
    } catch (e) {
      debugPrint('Error reacting to message: $e');
    }
  }

  Future<String?> uploadAttachment(File file) async {
    try {
      final formData = dio.FormData.fromMap({
        'attachment': await dio.MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _chatRepository.uploadAttachment(formData);
      if (response['success'] == true) {
        return response['mediaUrl'] ?? response['url'] ?? response['data']?['mediaUrl'] ?? response['data']?['url'];
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading attachment: $e');
      return null;
    }
  }

  Future<void> fetchUserStatus(String userId) async {
    try {
      final response = await _chatRepository.getUserStatus(userId);
      _currentUserStatus = response;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user status: $e');
    }
  }

  // User Search & Block
  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _searchedUsers = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _chatRepository.searchUsers(query);
      _searchedUsers = response;
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      await _chatRepository.blockUser(userId);
      _blockedUserIds.add(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await _chatRepository.unblockUser(userId);
      _blockedUserIds.remove(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error unblocking user: $e');
    }
  }

  Future<void> fetchBlockedUsers() async {
    try {
      final response = await _chatRepository.getBlockedUsers();
      if (response['success'] == true) {
        _blockedUserIds = (response['data'] as List).map((e) => e['_id'] as String).toSet();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
    }
  }

  Future<void> fetchPinnedMessages(String conversationId) async {
    try {
      final response = await _chatRepository.fetchPinnedMessages(conversationId);
      _pinnedMessages = response;

      // Decrypt pinned messages
      final partnerId = _activePartnerId ?? _conversations.firstWhere((c) => c.sId == conversationId, orElse: () => ConversationModel()).partner?.sId;
      if (partnerId != null && _pinnedMessages.isNotEmpty) {
        await _decryptMessagesList(_pinnedMessages, partnerId);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching pinned messages: $e');
    }
  }

  Future<void> pinMessage(String conversationId, String messageId) async {
    try {
      final response = await _chatRepository.pinMessage(messageId);
      if (response['success'] == true) {
        // Update local message state
        final updatedMsg = MessageModel.fromJson(response['data']);
        final index = _messages.indexWhere((m) => m.sId == messageId);
        if (index != -1) {
          _messages[index].isPinned = updatedMsg.isPinned;
          notifyListeners();
        }
        await fetchPinnedMessages(conversationId);
      }
    } catch (e) {
      debugPrint('Error pinning message: $e');
    }
  }

  Future<List<MessageModel>> searchInMessages(String query, {String? conversationId}) async {
    try {
      final List<MessageModel> combinedResults = [];
      final queryLower = query.toLowerCase();

      // 1. Local Search (Highest Accuracy for E2EE)
      if (conversationId == null || conversationId == _activeConversationId) {
        final localMatches = _messages.where((m) {
          if (m.messageType != 'text' || m.text == null) return false;
          return m.text!.toLowerCase().contains(queryLower);
        }).toList();
        combinedResults.addAll(localMatches);
      }

      // 2. Server Search
      final response = await _chatRepository.searchInMessages(query, conversationId: conversationId);
      final List<MessageModel> serverResults = response;
      
      // Resolve partnerId for decryption
      String? partnerId;
      if (conversationId != null) {
        final conv = _conversations.firstWhere((c) => c.sId == conversationId, orElse: () => ConversationModel());
        partnerId = conv.partner?.sId ?? conv.partner?.id;
      }
      partnerId ??= _activePartnerId;
      
      if (partnerId != null && serverResults.isNotEmpty) {
        await _decryptMessagesList(serverResults, partnerId);
      }

      // Merge and filter by DECRYPTED text
      for (var sMsg in serverResults) {
        if (sMsg.text != null && sMsg.text!.toLowerCase().contains(queryLower)) {
          if (!combinedResults.any((m) => m.sId == sMsg.sId)) {
            combinedResults.add(sMsg);
          }
        }
      }
      
      // Sort by date descending
      combinedResults.sort((a, b) {
        final aTime = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(0);
        final bTime = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(0);
        return bTime.compareTo(aTime);
      });

      return combinedResults;
    } catch (e) {
      debugPrint('Error searching in messages: $e');
      return [];
    }
  }
}
