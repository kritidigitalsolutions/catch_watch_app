import 'dart:convert';
import 'dart:io';

import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/data/network/socket_service.dart';
import 'package:catch_watch/models/chat_model.dart';
import 'package:catch_watch/repository/chat_repository.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/utils/encryption_helper.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart' as dio;
import 'package:agora_chat_sdk/agora_chat_sdk.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
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

  void reset() {
    _myKeyPair = null;
    _partnerPublicKeys.clear();
    _sharedSecrets.clear();
    _legacySharedSecrets.clear();
    _messages.clear();
    _conversations.clear();
    _searchedUsers.clear();
    _pinnedMessages.clear();
    _blockedUserIds.clear();
    _blockedByPartnerIds.clear();
    _processedMessageIds.clear();
    _processingFingerprints.clear();
    _activeConversationId = null;
    _activePartnerId = null;
    _replyingToMessage = null;
    _isPublicKeySyncing = false;
    _publicKeySavedOnServer = false;
    try {
      _socketService.disconnect();
    } catch (_) {}
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
    
    _partnerPublicKeys.clear();
    _sharedSecrets.clear();
    _legacySharedSecrets.clear();
    
    final userId = HiveService.userId;
    if (userId == null || userId.isEmpty) {
      debugPrint('E2EE: User not logged in, cannot initialize E2EE');
      return;
    }
    
    // Ensure Device ID exists
    if (HiveService.getDeviceId() == null) {
      final newDeviceId = 'dev_flutter_${Platform.isAndroid ? 'android' : 'ios'}_${const Uuid().v4().substring(0, 8)}';
      await HiveService.saveDeviceId(newDeviceId);
      debugPrint('E2EE: Generated new Device ID: $newDeviceId');
    }

    try {
      bool restoredFromBackup = false;

      // STEP 1: Always check server for account backup first to ensure parity with Web & other devices
      try {
        final backupResponse = await _chatRepository.getE2EEBackup();
        debugPrint('E2EE: Backup API Response: $backupResponse');

        Map<String, dynamic>? backupData;
        if (backupResponse is Map) {
          if (backupResponse['data'] is Map) {
            backupData = Map<String, dynamic>.from(backupResponse['data']);
          } else if (backupResponse['encryptedPrivateKeyBackup'] != null || backupResponse['backup'] != null) {
            backupData = Map<String, dynamic>.from(backupResponse);
          }
        }

        if (backupData != null) {
          final backup = backupData['encryptedPrivateKeyBackup'] ?? backupData['backup'];
          if (backup != null && backup is Map) {
            final ciphertext = backup['ciphertext'] ?? backup['encryptedKey'];
            final iv = backup['iv'] ?? backup['nonce'];
            final salt = backup['salt'];
            final iterations = backup['iterations'] ?? 100000;

            if (ciphertext != null && iv != null && salt != null) {
              debugPrint('E2EE: Decrypting account private key backup from server...');
              final decryptedPrivateKeyJwk = await EncryptionHelper.decryptBackup(
                ciphertext: ciphertext.toString(),
                iv: iv.toString(),
                salt: salt.toString(),
                iterations: iterations is int ? iterations : int.tryParse(iterations.toString()) ?? 100000,
                userId: userId,
              );

              if (decryptedPrivateKeyJwk != null && decryptedPrivateKeyJwk.isNotEmpty) {
                _myKeyPair = await EncryptionHelper.loadKeyPairFromPrivateJwk(decryptedPrivateKeyJwk);
                final derivedPublicJwk = EncryptionHelper.derivePublicKeyJwk(decryptedPrivateKeyJwk);
                final keyPairData = await _myKeyPair!.extract();
                
                if (keyPairData is EcKeyPairData && derivedPublicJwk != null) {
                  await HiveService.savePrivateKey(keyPairData.d, userId: userId);
                  await HiveService.savePublicKey(derivedPublicJwk, userId: userId);
                  _publicKeySavedOnServer = true;
                  restoredFromBackup = true;
                  debugPrint('✅ E2EE: KeyPair restored from server backup successfully! Identity synchronized with Website.');
                }
              }
            }
          }
        }
      } catch (backupErr) {
        debugPrint('E2EE: Failed to fetch/restore backup from server: $backupErr');
      }

      // STEP 2: If no server backup restored, try loading existing local key from Hive
      if (!restoredFromBackup) {
        final privateKeyBytes = HiveService.getPrivateKey(userId: userId);
        final savedJwk = HiveService.getPublicKey(userId: userId);

        if (privateKeyBytes != null && savedJwk != null) {
          debugPrint('E2EE: Loading local keys for user $userId...');
          try {
            _myKeyPair = await EncryptionHelper.loadKeyPair(privateKeyBytes, savedJwk);
            final myPublicKey = await _myKeyPair!.extractPublicKey();
            
            // Migration check: ensure P-256
            if (myPublicKey.type != KeyPairType.p256 || savedJwk.contains('"X25519"') || savedJwk.contains('"OKP"')) {
              _myKeyPair = null;
            } else {
              debugPrint('E2EE: Local KeyPair loaded successfully');
            }
          } catch (loadErr) {
            debugPrint('E2EE: Failed to load local keypair: $loadErr');
            _myKeyPair = null;
          }
        }
      }

      // STEP 3: If still no key pair, generate new P-256 key pair and register identity with backup on server
      if (_myKeyPair == null) {
        debugPrint('E2EE: Generating new P-256 KeyPair & registering identity with backup...');
        _myKeyPair = await EncryptionHelper.generateKeyPair();
        final keyPairData = await _myKeyPair!.extract();
        
        List<int> privBytes = [];
        if (keyPairData is EcKeyPairData) {
          privBytes = keyPairData.d;
        } else if (keyPairData is SimpleKeyPairData) {
          privBytes = keyPairData.bytes;
        }
        await HiveService.savePrivateKey(privBytes, userId: userId);

        final jwk = await EncryptionHelper.exportPublicKey(_myKeyPair!);
        await HiveService.savePublicKey(jwk, userId: userId);

        try {
          final keyId = 'p256_${DateTime.now().millisecondsSinceEpoch}';
          final deviceId = HiveService.getDeviceId() ?? 'mobile_device_1';

          String privJwkStr = jwk;
          if (keyPairData is EcKeyPairData) {
            privJwkStr = jsonEncode({
              'crv': 'P-256',
              'd': base64Url.encode(keyPairData.d).replaceAll('=', ''),
              'kty': 'EC',
              'x': base64Url.encode(keyPairData.x).replaceAll('=', ''),
              'y': base64Url.encode(keyPairData.y).replaceAll('=', ''),
            });
          }

          final backupPayload = await EncryptionHelper.encryptBackup(privJwkStr, userId);

          await _chatRepository.registerE2EEIdentity({
            'publicKey': jwk,
            'keyId': keyId,
            'deviceId': deviceId,
            'encryptedPrivateKeyBackup': backupPayload,
          });
          _publicKeySavedOnServer = true;
          debugPrint('E2EE: Identity & backup registered on server successfully');
        } catch (regErr) {
          debugPrint('E2EE: Failed to register identity & backup on server: $regErr');
        }
      }

      // STEP 4: Ensure public key is active on server
      if (_myKeyPair != null && !_publicKeySavedOnServer) {
        await syncPublicKey();
      }
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
      final keyPairData = await _myKeyPair!.extract();
      
      final userId = HiveService.userId ?? '';
      final deviceId = HiveService.getDeviceId() ?? 'mobile_device_1';
      final keyId = 'p256_${DateTime.now().millisecondsSinceEpoch}';

      // Always include zero-knowledge encrypted backup with identity registration
      if (keyPairData is EcKeyPairData && userId.isNotEmpty) {
        final privJwkStr = jsonEncode({
          'crv': 'P-256',
          'd': base64Url.encode(keyPairData.d).replaceAll('=', ''),
          'kty': 'EC',
          'x': base64Url.encode(keyPairData.x).replaceAll('=', ''),
          'y': base64Url.encode(keyPairData.y).replaceAll('=', ''),
        });
        final backupPayload = await EncryptionHelper.encryptBackup(privJwkStr, userId);

        final response = await _chatRepository.registerE2EEIdentity({
          'publicKey': jwkString,
          'keyId': keyId,
          'deviceId': deviceId,
          'encryptedPrivateKeyBackup': backupPayload,
        });

        if (response['success'] == true) {
          _publicKeySavedOnServer = true;
          debugPrint('✅ SUCCESS: Identity and backup registered on server');
          return;
        }
      }

      // Fallback
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
          try {
            final response = await _chatRepository.getUserPublicKey(partnerId);
            if (response['success'] == true) {
              // Flexible parsing of API response
              final data = response['data'] ?? response['user'] ?? response;
              partnerPublicKeyJwk = data is Map ? (data['publicKey'] ?? data['key']) : null;
            }
          } catch (_) {}
        }

        // 4. Fallback to Profile Stats API
        if (partnerPublicKeyJwk == null) {
          debugPrint('E2EE: Trying profile stats API for partner: $partnerId');
          try {
            final response = await _chatRepository.getOtherProfileStats(partnerId);
            final data = response is Map ? (response['data'] ?? response['user'] ?? response) : null;
            partnerPublicKeyJwk = data is Map ? (data['publicKey'] ?? data['key']) : null;
          } catch (_) {}
        }

        // 5. Fallback: Fetch conversations list to update metadata
        if (partnerPublicKeyJwk == null) {
          debugPrint('E2EE: Trying fetchConversations to get partner public key...');
          try {
            await fetchConversations();
            for (var conv in _conversations) {
              final p = conv.partner;
              if (p != null) {
                final pSid = p.sId?.toString();
                final pId = p.id?.toString();
                if ((pSid != null && pSid == partnerId) || (pId != null && pId == partnerId)) {
                  if (p.publicKey != null) {
                    partnerPublicKeyJwk = p.publicKey;
                    break;
                  }
                }
              }
            }
          } catch (_) {}
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
        final partnerId = (senderId != null && senderId != HiveService.userId) 
            ? senderId 
            : (_activePartnerId ?? (newMessage.conversationId != null ? _conversations.firstWhere((c) => c.sId == newMessage.conversationId, orElse: () => ConversationModel()).partner?.sId : null));

        if (partnerId != null) {
          await _decryptMessagesList([newMessage], partnerId);
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

    if (_myKeyPair == null) {
      await initE2EE();
    }
    
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

    if (_myKeyPair == null) {
      await initE2EE();
    }

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
      String? partnerId = _activePartnerId ?? _conversations.firstWhere((c) => c.sId == conversationId, orElse: () => ConversationModel()).partner?.sId;
      if (partnerId == null && newMessages.isNotEmpty) {
        final myUserId = HiveService.userId;
        for (var m in newMessages) {
          final sId = m.sender?.sId ?? m.sender?.id;
          if (sId != null && sId != myUserId) {
            partnerId = sId;
            break;
          }
          final rId = m.recipient is Sender
              ? (m.recipient as Sender).sId
              : (m.recipient is Map ? m.recipient['_id']?.toString() : m.recipient?.toString());
          if (rId != null && rId != myUserId) {
            partnerId = rId;
            break;
          }
        }
      }

      if (partnerId != null) {
        // Ensure partner public key is fetched/refreshed first before decryption
        await _getSharedSecret(partnerId, forceFetch: true);
      }
      await _decryptMessagesList(newMessages, partnerId);

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

  Future<void> _decryptMessagesList(List<MessageModel> messages, [String? fallbackPartnerId]) async {
    debugPrint('E2EE: Decrypting ${messages.length} messages using candidate keys...');
    
    if (_myKeyPair == null) {
      await initE2EE();
    }

    if (_myKeyPair == null) {
      debugPrint('E2EE WARNING: Cannot decrypt messages, _myKeyPair is still NULL');
      return;
    }

    final myUserId = HiveService.userId;

    // Collect historical public keys from across the message batch
    final Set<String> historicalCandidateJwks = {};
    for (var m in messages) {
      if (m.senderPublicKey != null && m.senderPublicKey!.isNotEmpty) {
        historicalCandidateJwks.add(m.senderPublicKey!);
      }
      if (m.recipientPublicKey != null && m.recipientPublicKey!.isNotEmpty) {
        historicalCandidateJwks.add(m.recipientPublicKey!);
      }
      if (m.encryptionMeta != null) {
        final spk = m.encryptionMeta!['senderPublicKey'];
        if (spk != null && spk is String && spk.isNotEmpty) historicalCandidateJwks.add(spk);
        final rpk = m.encryptionMeta!['recipientPublicKey'];
        if (rpk != null && rpk is String && rpk.isNotEmpty) historicalCandidateJwks.add(rpk);
        if (m.encryptionMeta!['envelopes'] is List) {
          for (var env in m.encryptionMeta!['envelopes']) {
            if (env is Map) {
              if (env['senderPublicKey'] != null) historicalCandidateJwks.add(env['senderPublicKey'].toString());
              if (env['recipientPublicKey'] != null) historicalCandidateJwks.add(env['recipientPublicKey'].toString());
            }
          }
        }
      }
      if (m.sender?.publicKey != null) {
        final spk = m.sender!.publicKey is String ? m.sender!.publicKey : jsonEncode(m.sender!.publicKey);
        historicalCandidateJwks.add(spk);
      }
      if (m.sender?.deviceKeys != null) {
        for (var dk in m.sender!.deviceKeys!) {
          final pk = dk is Map ? (dk['publicKey'] ?? dk['key']) : dk;
          if (pk != null) historicalCandidateJwks.add(pk is String ? pk : jsonEncode(pk));
        }
      }
      if (m.recipient is Sender && (m.recipient as Sender).publicKey != null) {
        final rpk = (m.recipient as Sender).publicKey;
        historicalCandidateJwks.add(rpk is String ? rpk : jsonEncode(rpk));
      }
      if (m.recipient is Sender && (m.recipient as Sender).deviceKeys != null) {
        for (var dk in (m.recipient as Sender).deviceKeys!) {
          final pk = dk is Map ? (dk['publicKey'] ?? dk['key']) : dk;
          if (pk != null) historicalCandidateJwks.add(pk is String ? pk : jsonEncode(pk));
        }
      }
    }

    for (var msg in messages) {
      if (msg.messageType == 'text' && msg.text != null && msg.text!.isNotEmpty) {
        if (msg.isDecrypted) continue;

        // If message is not encrypted (plain text), keep as-is and mark decrypted
        if (msg.isEncrypted != true && (msg.iv == null || msg.iv!.isEmpty)) {
          msg.isDecrypted = true;
          continue;
        }

        msg.cipherText = msg.text;

        final senderId = msg.sender?.sId ?? msg.sender?.id;
        final bool isSender = myUserId != null && (senderId == myUserId);
        final recipientId = msg.recipient is Sender
            ? (msg.recipient as Sender).sId
            : (msg.recipient is Map ? msg.recipient['_id']?.toString() : msg.recipient?.toString());
        final partnerId = isSender ? recipientId : senderId;
        final effectivePartnerId = partnerId ?? fallbackPartnerId ?? _activePartnerId;

        final List<dynamic> candidateKeyInputs = [];

        // 1. Primary sender / recipient keys from message
        if (!isSender) {
          if (msg.senderPublicKey != null && msg.senderPublicKey!.isNotEmpty) {
            candidateKeyInputs.add(msg.senderPublicKey!);
          }
          if (msg.encryptionMeta != null && msg.encryptionMeta!['senderPublicKey'] != null) {
            candidateKeyInputs.add(msg.encryptionMeta!['senderPublicKey']);
          }
          if (msg.sender != null && msg.sender!.publicKey != null) {
            candidateKeyInputs.add(msg.sender!.publicKey);
          }
          if (msg.sender != null && msg.sender!.deviceKeys != null) {
            for (var dk in msg.sender!.deviceKeys!) {
              final pk = dk is Map ? (dk['publicKey'] ?? dk['key']) : dk;
              if (pk != null) candidateKeyInputs.add(pk);
            }
          }
          if (msg.recipientPublicKey != null && msg.recipientPublicKey!.isNotEmpty) {
            candidateKeyInputs.add(msg.recipientPublicKey!);
          }
        } else {
          if (msg.recipientPublicKey != null && msg.recipientPublicKey!.isNotEmpty) {
            candidateKeyInputs.add(msg.recipientPublicKey!);
          }
          if (msg.encryptionMeta != null && msg.encryptionMeta!['recipientPublicKey'] != null) {
            candidateKeyInputs.add(msg.encryptionMeta!['recipientPublicKey']);
          }
          if (msg.recipient is Sender && (msg.recipient as Sender).publicKey != null) {
            candidateKeyInputs.add((msg.recipient as Sender).publicKey);
          }
          if (msg.recipient is Sender && (msg.recipient as Sender).deviceKeys != null) {
            for (var dk in (msg.recipient as Sender).deviceKeys!) {
              final pk = dk is Map ? (dk['publicKey'] ?? dk['key']) : dk;
              if (pk != null) candidateKeyInputs.add(pk);
            }
          }
          if (msg.senderPublicKey != null && msg.senderPublicKey!.isNotEmpty) {
            candidateKeyInputs.add(msg.senderPublicKey!);
          }
        }

        // 2. Partner keys from Hive & memory cache
        if (effectivePartnerId != null) {
          final partnerJwk = HiveService.getPartnerPublicKey(effectivePartnerId);
          if (partnerJwk != null) candidateKeyInputs.add(partnerJwk);
          if (_partnerPublicKeys.containsKey(effectivePartnerId)) {
            candidateKeyInputs.add(_partnerPublicKeys[effectivePartnerId]);
          }
        }

        // 3. Conversation metadata partner keys
        for (var conv in _conversations) {
          if (conv.sId == msg.conversationId || (effectivePartnerId != null && (conv.partner?.sId == effectivePartnerId || conv.partner?.id == effectivePartnerId))) {
            if (conv.partner?.publicKey != null) candidateKeyInputs.add(conv.partner!.publicKey);
            if (conv.partner?.deviceKeys != null) {
              for (var dk in conv.partner!.deviceKeys!) {
                final pk = dk is Map ? (dk['publicKey'] ?? dk['key']) : dk;
                if (pk != null) candidateKeyInputs.add(pk);
              }
            }
          }
        }

        // 4. Historical candidate keys from other messages in the batch
        candidateKeyInputs.addAll(historicalCandidateJwks);

        bool decryptedSuccessfully = false;

        // Try candidate keys
        for (var candidate in candidateKeyInputs) {
          try {
            PublicKey pubKey;
            if (candidate is PublicKey) {
              pubKey = candidate;
            } else {
              pubKey = await EncryptionHelper.importPublicKey(candidate);
            }

            final secret = await EncryptionHelper.deriveSharedSecret(_myKeyPair!, pubKey);
            final decrypted = await EncryptionHelper.decrypt(msg.text!, secret, iv: msg.iv);
            if (decrypted != msg.text && decrypted != msg.cipherText) {
              msg.text = decrypted;
              msg.isDecrypted = true;
              decryptedSuccessfully = true;

              if (effectivePartnerId != null) {
                final jwkStr = candidate is String ? candidate : jsonEncode(candidate);
                await HiveService.savePartnerPublicKey(effectivePartnerId, jwkStr);
                _partnerPublicKeys[effectivePartnerId] = pubKey;
              }
              break;
            }
          } catch (_) {}
        }

        // Fallback: If still not decrypted and effectivePartnerId is available, fetch latest public key & deviceKeys from API
        if (!decryptedSuccessfully && effectivePartnerId != null) {
          try {
            final response = await _chatRepository.getUserPublicKey(effectivePartnerId);
            if (response['success'] == true) {
              final data = response['data'] ?? response['user'] ?? response;
              final apiPubKey = data is Map ? (data['publicKey'] ?? data['key']) : null;
              final apiDeviceKeys = data is Map ? data['deviceKeys'] : null;

              final List<dynamic> apiCandidates = [];
              if (apiPubKey != null) apiCandidates.add(apiPubKey);
              if (apiDeviceKeys is List) {
                for (var dk in apiDeviceKeys) {
                  final pk = dk is Map ? (dk['publicKey'] ?? dk['key']) : dk;
                  if (pk != null) apiCandidates.add(pk);
                }
              }

              for (var candidate in apiCandidates) {
                try {
                  final pubKey = await EncryptionHelper.importPublicKey(candidate);
                  final secret = await EncryptionHelper.deriveSharedSecret(_myKeyPair!, pubKey);
                  final decrypted = await EncryptionHelper.decrypt(msg.text!, secret, iv: msg.iv);
                  if (decrypted != msg.text && decrypted != msg.cipherText) {
                    msg.text = decrypted;
                    msg.isDecrypted = true;
                    decryptedSuccessfully = true;

                    final jwkStr = candidate is String ? candidate : jsonEncode(candidate);
                    await HiveService.savePartnerPublicKey(effectivePartnerId, jwkStr);
                    _partnerPublicKeys[effectivePartnerId] = pubKey;
                    break;
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }

        // Fallback: Legacy shared secret
        if (!decryptedSuccessfully && effectivePartnerId != null) {
          try {
            final legacySecret = await _getLegacySharedSecret(effectivePartnerId);
            if (legacySecret != null) {
              final decrypted = await EncryptionHelper.decrypt(msg.text!, legacySecret, iv: msg.iv);
              if (decrypted != msg.text && decrypted != msg.cipherText) {
                msg.text = decrypted;
                msg.isDecrypted = true;
                decryptedSuccessfully = true;
              }
            }
          } catch (_) {}
        }

        // Fallback: Hashed secret
        if (!decryptedSuccessfully && effectivePartnerId != null) {
          try {
            PublicKey? pubKey = _partnerPublicKeys[effectivePartnerId];
            if (pubKey == null) {
              final partnerJwk = HiveService.getPartnerPublicKey(effectivePartnerId);
              if (partnerJwk != null) {
                pubKey = await EncryptionHelper.importPublicKey(partnerJwk);
              }
            }
            if (pubKey != null) {
              final hashedSecret = await EncryptionHelper.deriveSharedSecretHashed(_myKeyPair!, pubKey);
              final decrypted = await EncryptionHelper.decrypt(msg.text!, hashedSecret, iv: msg.iv);
              if (decrypted != msg.text && decrypted != msg.cipherText) {
                msg.text = decrypted;
                msg.isDecrypted = true;
                decryptedSuccessfully = true;
              }
            }
          } catch (_) {}
        }

        if (!decryptedSuccessfully) {
          debugPrint('E2EE WARNING: All decryption attempts failed for message ${msg.sId}');
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

      final myUserId = HiveService.userId ?? 'unknown_user';
      final myPublicKeyJwk = _myKeyPair != null
          ? await EncryptionHelper.exportPublicKey(_myKeyPair!)
          : HiveService.getPublicKey(userId: myUserId);
      final myDeviceId = HiveService.getDeviceId() ?? 'unknown_device';
      final partnerPublicKeyJwk = partnerId != null ? HiveService.getPartnerPublicKey(partnerId) : null;

      final Map<String, dynamic> data = {
        'conversationId': conversationId,
        'recipientId': partnerId,
        'isEncrypted': isEncrypted,
        'iv': iv ?? '',
        'messageType': messageType,
        'replyTo': actualReplyTo,
        'text': encryptedText ?? text ?? '', 
      };

      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        data['mediaUrl'] = mediaUrl;
        data['attachment'] = mediaUrl;
        data['fileUrl'] = mediaUrl;
      }

      if (isEncrypted && encryptedText != null && iv != null) {
        data['encryption'] = {
          'version': 2,
          'senderDeviceId': myDeviceId,
          'senderKeyId': 'key_$myUserId',
          'senderPublicKey': myPublicKeyJwk,
          'recipientDeviceId': 'dev_${partnerId}_01',
          'recipientKeyId': 'key_$partnerId',
          'recipientPublicKey': partnerPublicKeyJwk,
          'envelopes': [
            {
              'userId': partnerId,
              'deviceId': 'dev_${partnerId}_01',
              'keyId': 'key_$partnerId',
              'senderDeviceId': myDeviceId,
              'senderKeyId': 'key_$myUserId',
              'senderPublicKey': myPublicKeyJwk,
              'recipientPublicKey': partnerPublicKeyJwk,
              'ciphertext': encryptedText,
              'iv': iv,
            }
          ]
        };
        data['ciphertext'] = encryptedText;
        data['senderPublicKey'] = myPublicKeyJwk;
        data['recipientPublicKey'] = partnerPublicKeyJwk;
      }

      final response = await _chatRepository.sendMessage(data);
      if (response['success'] == true) {
        clearReplyingMessage();
        
        // OPTIMISTIC UPDATE: Add message to local list instead of re-fetching
        // This prevents the "blink" caused by fetchMessages(conversationId)
        final sentMessage = MessageModel.fromJson(response['data']);
        
        if (sentMessage.mediaUrl == null || sentMessage.mediaUrl!.isEmpty) {
          sentMessage.mediaUrl = mediaUrl;
        }

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

      final recipientPublicKeyJwk = HiveService.getPartnerPublicKey(recipientId);

      if (isEncrypted && textToForward != null && iv != null) {
        data['encryption'] = {
          'version': 2,
          'senderDeviceId': myDeviceId,
          'senderKeyId': 'key_$myUserId',
          'senderPublicKey': myPublicKeyJwk,
          'recipientDeviceId': 'dev_${recipientId}_01',
          'recipientKeyId': 'key_$recipientId',
          'recipientPublicKey': recipientPublicKeyJwk,
          'envelopes': [
            {
              'userId': recipientId,
              'deviceId': 'dev_${recipientId}_01',
              'keyId': 'key_$recipientId',
              'senderDeviceId': myDeviceId,
              'senderKeyId': 'key_$myUserId',
              'senderPublicKey': myPublicKeyJwk,
              'recipientPublicKey': recipientPublicKeyJwk,
              'ciphertext': textToForward,
              'iv': iv,
            }
          ]
        };
        data['ciphertext'] = textToForward;
        data['senderPublicKey'] = myPublicKeyJwk;
        data['recipientPublicKey'] = recipientPublicKeyJwk;
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
    if (!await file.exists()) {
      debugPrint('uploadAttachment ERROR: File does not exist at ${file.path}');
      return null;
    }

    final rawFilename = file.path.split('/').last;
    
    // Detect MIME type and ensure file has a valid extension for server image validators
    final detectedMime = lookupMimeType(file.path) ?? 'image/jpeg';
    
    String extension = '';
    if (rawFilename.contains('.')) {
      extension = rawFilename.split('.').last.toLowerCase();
    }
    
    String filename = rawFilename;
    if (extension.isEmpty || extension.length > 5 || RegExp(r'^\d+$').hasMatch(extension)) {
      final extFromMime = extensionFromMime(detectedMime) ?? 'jpg';
      filename = '$rawFilename.$extFromMime';
    }

    final contentType = dio.DioMediaType.parse(detectedMime);
    
    debugPrint('uploadAttachment: file=${file.path}, filename=$filename, mime=$detectedMime');

    String fixUrl(String rawUrl) {
      if (rawUrl.startsWith('http')) {
        return rawUrl.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      if (rawUrl.startsWith('/')) {
        return '${AppUrl.serverUrl}$rawUrl';
      }
      return '${AppUrl.serverUrl}/$rawUrl';
    }

    String? extractUrl(dynamic res) {
      if (res == null) return null;
      if (res is String && res.isNotEmpty) {
        return fixUrl(res);
      }
      if (res is Map) {
        final dataField = res['data'];
        if (dataField is String && dataField.isNotEmpty) {
          return fixUrl(dataField);
        } else if (dataField is Map) {
          final nestedUrl = dataField['mediaUrl'] ??
              dataField['fileUrl'] ??
              dataField['url'] ??
              dataField['secure_url'] ??
              dataField['attachmentUrl'] ??
              dataField['attachment'] ??
              dataField['path'] ??
              dataField['filePath'];
          if (nestedUrl != null && nestedUrl.toString().isNotEmpty) {
            return fixUrl(nestedUrl.toString());
          }
        }
        final topUrl = res['mediaUrl'] ??
            res['fileUrl'] ??
            res['url'] ??
            res['secure_url'] ??
            res['attachmentUrl'] ??
            res['attachment'] ??
            res['path'] ??
            res['filePath'];
        if (topUrl != null && topUrl.toString().isNotEmpty) {
          return fixUrl(topUrl.toString());
        }
      }
      return null;
    }

    final candidateFields = ['attachment', 'file', 'media', 'image'];

    for (final fieldName in candidateFields) {
      try {
        final formData = dio.FormData.fromMap({
          fieldName: await dio.MultipartFile.fromFile(
            file.path, 
            filename: filename,
            contentType: contentType,
          ),
        });

        debugPrint('Attempting attachment upload with field name: $fieldName');
        final response = await _chatRepository.uploadAttachment(formData);
        debugPrint('Upload attachment response ($fieldName): $response');

        final parsedUrl = extractUrl(response);
        if (parsedUrl != null) {
          return parsedUrl;
        }
      } catch (e) {
        debugPrint('Error uploading attachment with field $fieldName (with contentType): $e');
        // Fallback without contentType
        try {
          final formDataFallback = dio.FormData.fromMap({
            fieldName: await dio.MultipartFile.fromFile(
              file.path, 
              filename: filename,
            ),
          });
          debugPrint('Attempting fallback attachment upload without contentType: $fieldName');
          final response = await _chatRepository.uploadAttachment(formDataFallback);
          final parsedUrl = extractUrl(response);
          if (parsedUrl != null) {
            return parsedUrl;
          }
        } catch (e2) {
          debugPrint('Error uploading attachment fallback with field $fieldName: $e2');
        }
      }
    }
    return null;
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
