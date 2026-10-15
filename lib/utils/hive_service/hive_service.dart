import 'dart:convert';
import 'package:catch_watch/utils/encryption_helper.dart';
import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:catch_watch/utils/hive_service/userdetail.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String boxName = 'userBox';
  static const String userKey = 'user';
  static const String historyBoxName = 'historyBox';
  static const String likesBoxName = 'likesBox';
  static const String statsBoxName = 'statsBox';
  static const String keysBoxName = 'keysBox';
  static const String appSettingsBoxName = 'appSettingsBox';
  static const String onboardingCompletedKey = 'has_completed_onboarding';

  // --- Secure Storage Keys & Configuration ---
  static const String _secureTokenKey = 'catch_watch_auth_token';
  static const String _securePrivateKeyKey = 'catch_watch_e2ee_private_key';
  static const String _securePublicKeyKey = 'catch_watch_e2ee_public_key';
  static const String _securePrivateKeyPrefix = 'catch_watch_e2ee_priv_';
  static const String _securePublicKeyPrefix = 'catch_watch_e2ee_pub_';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // In-memory cache loaded securely for synchronous access
  static String? _cachedToken;
  static List<int>? _cachedPrivateKey;
  static String? _cachedKeyUserId;

  static String _scopedPrivateKeyKey(String uid) => '$_securePrivateKeyPrefix$uid';
  static String _scopedPublicKeyKey(String uid) => '$_securePublicKeyPrefix$uid';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserDetailsAdapter());
    }
    await Hive.openBox<UserDetails>(boxName);
    await Hive.openBox(historyBoxName);
    await Hive.openBox(likesBoxName);
    await Hive.openBox(statsBoxName);
    await Hive.openBox(keysBoxName);
    await Hive.openBox(appSettingsBoxName);

    // Safely migrate existing plaintext secrets from Hive to Secure Storage
    await _migrateSecretsFromHive();
  }

  /// Idempotent migration of legacy plaintext tokens and E2EE private keys
  /// from Hive boxes to hardware-backed Secure Storage (KeyStore / Keychain).
  static Future<void> _migrateSecretsFromHive() async {
    try {
      final currentUid = userId;

      // 1. Migrate JWT Auth Token
      String? secureToken;
      try {
        secureToken = await _secureStorage.read(key: _secureTokenKey);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [SECURE_STORAGE] Failed to read auth token: $e');
        }
      }

      final user = _box.get(userKey);
      final hiveToken = user?.token;

      if (user != null && hiveToken != null && hiveToken.trim().isNotEmpty) {
        final UserDetails currentUser = user;
        final trimmedHiveToken = hiveToken.trim();
        if (secureToken == null || secureToken.isEmpty) {
          // Write to secure storage and verify before modifying Hive
          await _secureStorage.write(key: _secureTokenKey, value: trimmedHiveToken);
          final verified = await _secureStorage.read(key: _secureTokenKey);
          if (verified == trimmedHiveToken) {
            secureToken = verified;
            // Persistence confirmed: scrub plaintext token from Hive record
            currentUser.token = null;
            await _box.put(userKey, currentUser);
            if (kDebugMode) {
              debugPrint('🔒 [SECURE_STORAGE] Successfully migrated JWT token to secure storage');
            }
          }
        } else {
          // Secure storage already has the token: scrub plaintext copy from Hive
          currentUser.token = null;
          await _box.put(userKey, currentUser);
        }
      }
      _cachedToken = secureToken;

      // 2. Migrate E2EE Private Key
      List<int>? privateKeyBytes;
      if (currentUid != null && currentUid.isNotEmpty) {
        try {
          final scopedKeyStr = await _secureStorage.read(key: _scopedPrivateKeyKey(currentUid));
          if (scopedKeyStr != null && scopedKeyStr.isNotEmpty) {
            privateKeyBytes = base64Decode(scopedKeyStr);
            _cachedKeyUserId = currentUid;
          }
        } catch (_) {}
      }

      if (privateKeyBytes == null) {
        try {
          final legacyKeyStr = await _secureStorage.read(key: _securePrivateKeyKey);
          if (legacyKeyStr != null && legacyKeyStr.isNotEmpty) {
            privateKeyBytes = base64Decode(legacyKeyStr);
            if (currentUid != null && currentUid.isNotEmpty) {
              _cachedKeyUserId = currentUid;
              // Adopt into scoped key for active user and remove unscoped key to prevent exposure
              await _secureStorage.write(key: _scopedPrivateKeyKey(currentUid), value: legacyKeyStr);
              await _secureStorage.delete(key: _securePrivateKeyKey);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [SECURE_STORAGE] Failed to read E2EE private key: $e');
          }
        }
      }

      // Check Hive legacy storage if secure storage did not have it
      if (_keysBox.containsKey('privateKey')) {
        final hiveKeyData = _keysBox.get('privateKey');
        if (hiveKeyData is List) {
          final hiveKeyBytes = List<int>.from(hiveKeyData);
          if (hiveKeyBytes.isNotEmpty) {
            if (privateKeyBytes == null || privateKeyBytes.isEmpty) {
              final b64 = base64Encode(hiveKeyBytes);
              if (currentUid != null && currentUid.isNotEmpty) {
                await _secureStorage.write(key: _scopedPrivateKeyKey(currentUid), value: b64);
                final verifiedStr = await _secureStorage.read(key: _scopedPrivateKeyKey(currentUid));
                if (verifiedStr != null) {
                  final verifiedBytes = base64Decode(verifiedStr);
                  if (listEquals(verifiedBytes, hiveKeyBytes)) {
                    privateKeyBytes = verifiedBytes;
                    _cachedKeyUserId = currentUid;
                    await _keysBox.delete('privateKey');
                    if (kDebugMode) {
                      debugPrint('🔒 [SECURE_STORAGE] Successfully migrated E2EE private key to user-scoped secure storage');
                    }
                  }
                }
              } else {
                // If no user is authenticated yet, temporarily store until first login
                await _secureStorage.write(key: _securePrivateKeyKey, value: b64);
                await _keysBox.delete('privateKey');
              }
            } else {
              // Secure storage already has key: delete plaintext copy from Hive
              await _keysBox.delete('privateKey');
            }
          }
        }
      }
      _cachedPrivateKey = currentUid != null ? privateKeyBytes : null;

      // 3. Migrate Public Key if present in Hive
      if (_keysBox.containsKey('publicKey')) {
        final hivePub = _keysBox.get('publicKey');
        if (hivePub != null && hivePub is String && hivePub.isNotEmpty) {
          if (currentUid != null && currentUid.isNotEmpty) {
            await _secureStorage.write(key: _scopedPublicKeyKey(currentUid), value: hivePub);
            await _keysBox.put('publicKey_$currentUid', hivePub);
            await _keysBox.delete('publicKey');
          } else {
            await _secureStorage.write(key: _securePublicKeyKey, value: hivePub);
            await _keysBox.delete('publicKey');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [SECURE_STORAGE] Migration encountered an error: $e');
      }
    }
  }

  static Box<UserDetails> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw HiveError('Box not found. Did you forget to call Hive.openBox()?');
    }
    return Hive.box<UserDetails>(boxName);
  }

  static Box get _historyBox => Hive.box(historyBoxName);
  static Box get _likesBox => Hive.box(likesBoxName);
  static Box get _statsBox => Hive.box(statsBoxName);
  static Box get _keysBox => Hive.box(keysBoxName);

  /// Saves user details. Moves any non-empty JWT token to Secure Storage
  /// and strips the plaintext token before persisting the UserDetails object to Hive.
  /// Also proactively loads/adopts user-scoped E2EE keys.
  static Future<void> saveUser(UserDetails user) async {
    if (user.token != null && user.token!.trim().isNotEmpty) {
      final token = user.token!.trim();
      _cachedToken = token;
      await _secureStorage.write(key: _secureTokenKey, value: token);
      user.token = null; // Ensure token is never written to plaintext Hive storage
    }
    await _box.put(userKey, user);

    final uid = user.sId;
    if (uid != null && uid.isNotEmpty) {
      await _loadOrAdoptUserKeys(uid);
    }
  }

  /// Proactively loads or adopts E2EE keys for [uid] from Secure Storage.
  static Future<void> _loadOrAdoptUserKeys(String uid) async {
    try {
      // 1. Check if user already has a scoped private key in Secure Storage
      final scopedKeyStr = await _secureStorage.read(key: _scopedPrivateKeyKey(uid));
      if (scopedKeyStr != null && scopedKeyStr.isNotEmpty) {
        _cachedPrivateKey = base64Decode(scopedKeyStr);
        _cachedKeyUserId = uid;
        return;
      }

      // 2. Check if an unassigned legacy key exists from an upgrade
      final legacyKeyStr = await _secureStorage.read(key: _securePrivateKeyKey);
      if (legacyKeyStr != null && legacyKeyStr.isNotEmpty) {
        final decoded = base64Decode(legacyKeyStr);
        _cachedPrivateKey = decoded;
        _cachedKeyUserId = uid;
        // Adopt into scoped key for this user
        await _secureStorage.write(key: _scopedPrivateKeyKey(uid), value: legacyKeyStr);
        // Delete legacy unscoped key so another user cannot adopt it
        await _secureStorage.delete(key: _securePrivateKeyKey);

        // Also adopt legacy public key if available
        final legacyPub = await _secureStorage.read(key: _securePublicKeyKey);
        if (legacyPub != null && legacyPub.isNotEmpty) {
          await _secureStorage.write(key: _scopedPublicKeyKey(uid), value: legacyPub);
          await _secureStorage.delete(key: _securePublicKeyKey);
          if (Hive.isBoxOpen(keysBoxName)) {
            await _keysBox.put('publicKey_$uid', legacyPub);
          }
        }
        return;
      }

      // 3. Clear cache if this user has no key yet
      _cachedPrivateKey = null;
      _cachedKeyUserId = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [SECURE_STORAGE] Error in _loadOrAdoptUserKeys: $e');
      }
    }
  }

  /// Explicitly saves or updates the JWT auth token into Secure Storage.
  static Future<void> saveToken(String token) async {
    final trimmed = token.trim();
    _cachedToken = trimmed;
    await _secureStorage.write(key: _secureTokenKey, value: trimmed);
    final user = _box.get(userKey);
    if (user != null && user.token != null) {
      user.token = null;
      await _box.put(userKey, user);
    }
  }

  // --- Likes ---
  static Future<void> toggleLikeLocal(String contentId, bool isLiked) async {
    if (isLiked) {
      await _likesBox.put(contentId, true);
    } else {
      await _likesBox.delete(contentId);
    }
  }

  static Set<String> getLikedIds() {
    return _likesBox.keys.map((e) => e.toString()).toSet();
  }

  // --- Watch History ---
  static Future<void> saveWatchHistory(String contentId, Map<String, dynamic> data) async {
    await _historyBox.put(contentId, data);
  }

  static Future<void> removeFromWatchHistory(String contentId) async {
    await _historyBox.delete(contentId);
  }

  static Map<dynamic, dynamic> getWatchHistory() {
    return _historyBox.toMap();
  }

  /// Retrieves user details from Hive, populating the in-memory token field
  /// from Secure Storage for downstream consumers without persisting it to disk.
  static UserDetails? getUser() {
    if (!Hive.isBoxOpen(boxName)) return null;
    final user = _box.get(userKey);
    if (user != null) {
      user.token = _cachedToken;
    }
    return user;
  }

  /// Synchronously returns the JWT auth token from the securely loaded in-memory cache.
  static String? getToken() {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    if (!Hive.isBoxOpen(boxName)) return null;
    return _box.get(userKey)?.token;
  }

  /// Asynchronously fetches the token directly from Secure Storage if needed.
  static Future<String?> getTokenSecure() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    try {
      final token = await _secureStorage.read(key: _secureTokenKey);
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        return token;
      }
    } catch (_) {}
    return _box.get(userKey)?.token;
  }

  /// Extracts user ID from JWT token payload without external libraries.
  static String? getUserIdFromJwt(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(payloadString);
      if (map is Map) {
        final uid = map['id'] ?? map['_id'] ?? map['userId'] ?? map['sub'];
        if (uid != null && uid.toString().trim().isNotEmpty) {
          return uid.toString().trim();
        }
      }
    } catch (_) {}
    return null;
  }

  static String? get userId {
    if (Hive.isBoxOpen(boxName)) {
      final hiveUid = _box.get(userKey)?.sId;
      if (hiveUid != null && hiveUid.trim().isNotEmpty) {
        return hiveUid.trim();
      }
    }
    // Fallback: extract userId from authenticated JWT token in memory or storage
    return getUserIdFromJwt(getToken());
  }

  /// Asynchronously fetches userId, checking Hive first and falling back to SecureStorage JWT.
  static Future<String?> getUserIdSecure() async {
    final uid = userId;
    if (uid != null && uid.trim().isNotEmpty) {
      return uid.trim();
    }
    final secureToken = await getTokenSecure();
    return getUserIdFromJwt(secureToken);
  }

  /// Logs out the user session. Clears the JWT auth token from Secure Storage
  /// and wipes local user session boxes.
  /// 
  /// NOTE: Preserves the user's E2EE private and public keys in Secure Storage
  /// so that logging back into this account on this device can reuse the existing key pair
  /// and decrypt historical messages. Keys are scoped by user ID to prevent cross-account exposure.
  static Future<void> logout() async {
    _cachedToken = null;
    _cachedPrivateKey = null;
    _cachedKeyUserId = null;
    try {
      await _secureStorage.delete(key: _secureTokenKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [SECURE_STORAGE] Error deleting auth token on logout: $e');
      }
    }
    await _box.clear();
    await _historyBox.clear();
    await _likesBox.clear();
    await _statsBox.clear();
    // Clear ephemeral partner JWKs on logout
    if (Hive.isBoxOpen(keysBoxName)) {
      final keysToDelete = _keysBox.keys.where((k) => k.toString().startsWith('partner_jwk_')).toList();
      for (final k in keysToDelete) {
        await _keysBox.delete(k);
      }
    }
  }

  /// Permanently removes all user credentials, session data, AND E2EE private/public keys
  /// from Secure Storage and Hive upon confirmed account deletion.
  static Future<void> deleteAccountPermanent() async {
    final uid = userId;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _secureStorage.delete(key: _scopedPrivateKeyKey(uid));
        await _secureStorage.delete(key: _scopedPublicKeyKey(uid));
        if (Hive.isBoxOpen(keysBoxName)) {
          await _keysBox.delete('privateKey_$uid');
          await _keysBox.delete('publicKey_$uid');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [SECURE_STORAGE] Error deleting scoped keys on account deletion: $e');
        }
      }
    }

    try {
      await _secureStorage.delete(key: _securePrivateKeyKey);
      await _secureStorage.delete(key: _securePublicKeyKey);
      if (Hive.isBoxOpen(keysBoxName)) {
        await _keysBox.delete('privateKey');
        await _keysBox.delete('publicKey');
      }
    } catch (_) {}

    await logout();
  }

  // --- User Stats Cache ---
  static Future<void> saveUserStats(String userId, int followers, int following, int reels) async {
    await _statsBox.put(userId, {
      'followers': followers,
      'following': following,
      'reels': reels,
    });
  }

  static Map<String, int>? getUserStats(String userId) {
    final data = _statsBox.get(userId);
    if (data == null) return null;
    return Map<String, int>.from(data);
  }

  // --- E2EE Keys ---

  /// Persists E2EE private key bytes to hardware-backed Secure Storage.
  /// Scopes the key to [targetUserId] or the currently authenticated user (`userId`).
  /// Always normalizes key bytes to strictly 32 bytes (removes 33-byte sign prefix).
  static Future<void> savePrivateKey(List<int> bytes, {String? targetUserId}) async {
    final uid = targetUserId ?? userId;
    if (uid == null || uid.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ [SECURE_STORAGE] Cannot save private key without a valid user ID.');
      }
      return;
    }

    final normalized = EncryptionHelper.normalizeBytes(bytes, 32);
    _cachedPrivateKey = List<int>.from(normalized);
    _cachedKeyUserId = uid;
    final b64 = base64Encode(normalized);

    await _secureStorage.write(key: _scopedPrivateKeyKey(uid), value: b64);

    if (Hive.isBoxOpen(keysBoxName)) {
      await _keysBox.delete('privateKey');
      await _keysBox.delete('privateKey_$uid');
    }
  }

  /// Synchronously returns the E2EE private key from securely loaded memory (strictly normalized 32 bytes).
  /// Strictly verifies that the cached key belongs to [targetUserId] or current `userId`.
  static List<int>? getPrivateKey({String? targetUserId}) {
    final uid = targetUserId ?? userId;
    if (uid == null || uid.isEmpty) return null;
    if (_cachedPrivateKey != null && _cachedKeyUserId == uid) {
      return List<int>.from(EncryptionHelper.normalizeBytes(_cachedPrivateKey!, 32));
    }
    return null;
  }

  /// Asynchronously retrieves the E2EE private key directly from Secure Storage,
  /// scoped to [targetUserId] or `userId`. Always returns strictly normalized 32-byte bytes.
  static Future<List<int>?> getPrivateKeySecure({String? targetUserId}) async {
    final uid = targetUserId ?? userId;
    if (uid == null || uid.isEmpty) return null;

    if (_cachedPrivateKey != null && _cachedKeyUserId == uid) {
      return List<int>.from(EncryptionHelper.normalizeBytes(_cachedPrivateKey!, 32));
    }

    try {
      final scopedKeyStr = await _secureStorage.read(key: _scopedPrivateKeyKey(uid));
      if (scopedKeyStr != null && scopedKeyStr.isNotEmpty) {
        final decoded = base64Decode(scopedKeyStr);
        final normalized = EncryptionHelper.normalizeBytes(decoded, 32);
        _cachedPrivateKey = normalized;
        _cachedKeyUserId = uid;
        return List<int>.from(normalized);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [SECURE_STORAGE] Error reading scoped private key: $e');
      }
    }

    // Adopt unassigned legacy key only if this user has no scoped key yet
    try {
      final legacyKeyStr = await _secureStorage.read(key: _securePrivateKeyKey);
      if (legacyKeyStr != null && legacyKeyStr.isNotEmpty) {
        final decoded = base64Decode(legacyKeyStr);
        final normalized = EncryptionHelper.normalizeBytes(decoded, 32);
        _cachedPrivateKey = normalized;
        _cachedKeyUserId = uid;
        await _secureStorage.write(key: _scopedPrivateKeyKey(uid), value: base64Encode(normalized));
        await _secureStorage.delete(key: _securePrivateKeyKey);
        return List<int>.from(normalized);
      }
    } catch (_) {}

    return null;
  }

  /// Permanently deletes private key for [targetUserId] or `userId` from Secure Storage and cache.
  static Future<void> deletePrivateKey({String? targetUserId}) async {
    final uid = targetUserId ?? userId;
    if (_cachedKeyUserId == uid) {
      _cachedPrivateKey = null;
      _cachedKeyUserId = null;
    }
    if (uid != null && uid.isNotEmpty) {
      try {
        await _secureStorage.delete(key: _scopedPrivateKeyKey(uid));
        if (Hive.isBoxOpen(keysBoxName)) {
          await _keysBox.delete('privateKey_$uid');
        }
      } catch (_) {}
    }
    try {
      await _secureStorage.delete(key: _securePrivateKeyKey);
      if (Hive.isBoxOpen(keysBoxName)) {
        await _keysBox.delete('privateKey');
      }
    } catch (_) {}
  }

  static String? _cachedPublicKey;
  static String? _cachedPublicKeyUserId;

  /// Permanently deletes public key for [targetUserId] or `userId` from Secure Storage and Hive.
  static Future<void> deletePublicKey({String? targetUserId}) async {
    final uid = targetUserId ?? userId;
    if (_cachedPublicKeyUserId == uid || uid == null) {
      _cachedPublicKey = null;
      _cachedPublicKeyUserId = null;
    }
    if (uid != null && uid.isNotEmpty) {
      try {
        await _secureStorage.delete(key: _scopedPublicKeyKey(uid));
        if (Hive.isBoxOpen(keysBoxName)) {
          await _keysBox.delete('publicKey_$uid');
        }
      } catch (_) {}
    }
    try {
      await _secureStorage.delete(key: _securePublicKeyKey);
      if (Hive.isBoxOpen(keysBoxName)) {
        await _keysBox.delete('publicKey');
      }
    } catch (_) {}
  }

  /// Persists public key JWK to Secure Storage and Hive, scoped to [targetUserId] or `userId`.
  static Future<void> savePublicKey(String jwk, {String? targetUserId}) async {
    final uid = targetUserId ?? userId;
    final clean = jwk.trim();
    if (clean.isEmpty) return;

    _cachedPublicKey = clean;
    if (uid != null && uid.isNotEmpty) {
      _cachedPublicKeyUserId = uid;
      await _secureStorage.write(key: _scopedPublicKeyKey(uid), value: clean);
      if (Hive.isBoxOpen(keysBoxName)) {
        await _keysBox.put('publicKey_$uid', clean);
      }
    }

    // Always keep an un-scoped fallback in Hive so synchronous getPublicKey never fails
    if (Hive.isBoxOpen(keysBoxName)) {
      await _keysBox.put('publicKey', clean);
    }
  }

  /// Synchronously returns public key JWK scoped to [targetUserId] or `userId`.
  static String? getPublicKey({String? targetUserId}) {
    final uid = targetUserId ?? userId;
    if (_cachedPublicKey != null && _cachedPublicKey!.isNotEmpty) {
      if (uid == null || _cachedPublicKeyUserId == null || _cachedPublicKeyUserId == uid) {
        return _cachedPublicKey;
      }
    }

    if (Hive.isBoxOpen(keysBoxName)) {
      if (uid != null && uid.isNotEmpty) {
        final scoped = _keysBox.get('publicKey_$uid');
        if (scoped != null && scoped.toString().trim().isNotEmpty) {
          final clean = scoped.toString().trim();
          _cachedPublicKey = clean;
          _cachedPublicKeyUserId = uid;
          return clean;
        }
      }
      final fallback = _keysBox.get('publicKey');
      if (fallback != null && fallback.toString().trim().isNotEmpty) {
        final clean = fallback.toString().trim();
        _cachedPublicKey = clean;
        return clean;
      }
    }
    return null;
  }

  /// Asynchronously retrieves public key JWK from Secure Storage or Hive scoped to [targetUserId] or `userId`.
  static Future<String?> getPublicKeySecure({String? targetUserId}) async {
    final uid = targetUserId ?? userId;

    if (_cachedPublicKey != null && _cachedPublicKey!.isNotEmpty) {
      if (uid == null || _cachedPublicKeyUserId == null || _cachedPublicKeyUserId == uid) {
        return _cachedPublicKey;
      }
    }

    if (uid != null && uid.isNotEmpty) {
      try {
        final scopedPub = await _secureStorage.read(key: _scopedPublicKeyKey(uid));
        if (scopedPub != null && scopedPub.trim().isNotEmpty) {
          final clean = scopedPub.trim();
          _cachedPublicKey = clean;
          _cachedPublicKeyUserId = uid;
          if (Hive.isBoxOpen(keysBoxName)) {
            await _keysBox.put('publicKey_$uid', clean);
            await _keysBox.put('publicKey', clean);
          }
          return clean;
        }
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('⚠️ [SECURE_STORAGE] Error reading scoped public key: $e\n$stack');
        }
      }
    }

    if (Hive.isBoxOpen(keysBoxName)) {
      if (uid != null && uid.isNotEmpty) {
        final hiveScoped = _keysBox.get('publicKey_$uid');
        if (hiveScoped != null && hiveScoped.toString().trim().isNotEmpty) {
          final clean = hiveScoped.toString().trim();
          _cachedPublicKey = clean;
          _cachedPublicKeyUserId = uid;
          return clean;
        }
      }
      final hiveFallback = _keysBox.get('publicKey');
      if (hiveFallback != null && hiveFallback.toString().trim().isNotEmpty) {
        final clean = hiveFallback.toString().trim();
        _cachedPublicKey = clean;
        return clean;
      }
    }

    // Adopt unassigned legacy public key if available
    try {
      final legacyPub = await _secureStorage.read(key: _securePublicKeyKey);
      if (legacyPub != null && legacyPub.trim().isNotEmpty) {
        final clean = legacyPub.trim();
        _cachedPublicKey = clean;
        if (uid != null && uid.isNotEmpty) {
          _cachedPublicKeyUserId = uid;
          await _secureStorage.write(key: _scopedPublicKeyKey(uid), value: clean);
          await _secureStorage.delete(key: _securePublicKeyKey);
        }
        if (Hive.isBoxOpen(keysBoxName)) {
          if (uid != null && uid.isNotEmpty) {
            await _keysBox.put('publicKey_$uid', clean);
          }
          await _keysBox.put('publicKey', clean);
        }
        return clean;
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('⚠️ [SECURE_STORAGE] Error reading legacy public key: $e\n$stack');
      }
    }

    return null;
  }

  static Future<void> saveDeviceId(String deviceId) async {
    await _keysBox.put('deviceId', deviceId);
  }

  static String? getDeviceId() {
    return _keysBox.get('deviceId');
  }

  static Future<void> savePartnerPublicKey(String partnerId, String jwk) async {
    await _keysBox.put('partner_jwk_$partnerId', jwk);
  }

  static String? getPartnerPublicKey(String partnerId) {
    return _keysBox.get('partner_jwk_$partnerId');
  }

  static Future<void> deletePartnerPublicKey(String partnerId) async {
    await _keysBox.delete('partner_jwk_$partnerId');
  }

  static bool isLogin() {
    if (!Hive.isBoxOpen(boxName)) return false;
    final user = getUser();
    final token = getToken();
    return user != null && token != null && token.isNotEmpty;
  }

  static bool isProfileComplete() {
    if (!Hive.isBoxOpen(boxName)) return false;
    final user = getUser();
    return user != null && user.isNewUser == false;
  }

  // --- Onboarding Persistence ---
  static Box get _appSettingsBox => Hive.box(appSettingsBoxName);

  static Future<void> setOnboardingCompleted(bool completed) async {
    await _appSettingsBox.put(onboardingCompletedKey, completed);
  }

  static bool isOnboardingCompleted() {
    if (!Hive.isBoxOpen(appSettingsBoxName)) return false;
    return _appSettingsBox.get(onboardingCompletedKey, defaultValue: false) == true;
  }
}
