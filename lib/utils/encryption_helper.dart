import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class EncryptionHelper {
  // Use P-256 for standard E2EE compatibility
  static final _p256 = Ecdh.p256(length: 32);
  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Converts a BigInt to a fixed-length unsigned big-endian byte array (default 32 bytes).
  /// Guarantees exact [length] bytes: no sign byte (0x00) is prepended, and left-padded with zeros if needed.
  static Uint8List _bigIntToBytes(BigInt number, [int length = 32]) {
    if (number == BigInt.zero) {
      return Uint8List(length);
    }
    final positive = number.isNegative ? (-number) : number;
    var hex = positive.toRadixString(16);
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }
    final rawBytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      rawBytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return _normalizeBytes(rawBytes, length);
  }

  /// Public helper to convert BigInt to fixed 32-byte array
  static Uint8List bigIntToBytes(BigInt number, [int length = 32]) => _bigIntToBytes(number, length);

  /// Converts an unsigned big-endian byte array to BigInt
  static BigInt bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b & 0xff);
    }
    return result;
  }

  /// Normalizes byte list to exactly [length] bytes (default 32 for P-256).
  /// - If 33 bytes and first byte is 0x00 (sign byte from BigInt), removes the leading 0.
  /// - If longer than [length], strips leading 0x00 bytes. If still too long, takes the last [length] bytes.
  /// - If shorter than [length], left-pads with zeros.
  /// - If exactly [length] bytes, returns as Uint8List.
  static Uint8List _normalizeBytes(List<int> bytes, [int length = 32]) {
    if (bytes.length == length) {
      return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    }

    // Specific case: 33 bytes with leading 0x00 sign byte -> strip it immediately
    if (bytes.length == length + 1 && bytes.first == 0) {
      return Uint8List.fromList(bytes.sublist(1));
    }

    if (bytes.length > length) {
      // Remove leading zeros if present
      int start = 0;
      while (start < bytes.length - length && bytes[start] == 0) {
        start++;
      }
      final stripped = bytes.sublist(start);
      if (stripped.length == length) {
        return Uint8List.fromList(stripped);
      }
      if (stripped.length > length) {
        // Truncate from left, keep the least significant length bytes
        return Uint8List.fromList(stripped.sublist(stripped.length - length));
      }
      bytes = stripped;
    }

    // Left-pad with zeros
    final padded = Uint8List(length);
    padded.setRange(length - bytes.length, length, bytes);
    return padded;
  }

  /// Public helper to normalize bytes to [length] (default 32 bytes)
  static Uint8List normalizeBytes(List<int> bytes, [int length = 32]) => _normalizeBytes(bytes, length);

  static String _padBase64(String input) {
    int length = input.length;
    int mod = length % 4;
    if (mod == 0) return input;
    return input.padRight(length + (4 - mod), '=');
  }

  /// Legacy helper for older Android fallbacks
  static List<int> _ensurePositive(List<int> bytes) {
    if (bytes.isEmpty) return bytes;
    if (bytes[0] >= 128) {
      return [0, ...bytes];
    }
    return bytes;
  }

  // Generate a new key pair
  static Future<KeyPair> generateKeyPair() async {
    try {
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Generating new P-256 KeyPair...');
      }
      final keyPair = await _p256.newKeyPair();
      final keyPairData = await keyPair.extract();

      final normD = _normalizeBytes(keyPairData.d, 32);
      final normX = _normalizeBytes(keyPairData.x, 32);
      final normY = _normalizeBytes(keyPairData.y, 32);

      if (kDebugMode) {
        debugPrint('EncryptionHelper [generateKeyPair]: d.length=${normD.length}, x.length=${normX.length}, y.length=${normY.length}');
      }

      return EcKeyPairData(
        d: normD,
        x: normX,
        y: normY,
        type: KeyPairType.p256,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Error generating KeyPair: $e\n$stack');
      }
      rethrow;
    }
  }

  // Export Public Key to JWK from PublicKey or KeyPair
  static String exportPublicKeyJwk(dynamic key) {
    try {
      Map<String, dynamic> jwk;
      
      if (key is EcPublicKey) {
        final xNorm = _normalizeBytes(key.x, 32);
        final yNorm = _normalizeBytes(key.y, 32);

        if (kDebugMode) {
          debugPrint('EncryptionHelper [exportPublicKeyJwk]: x.length=${xNorm.length}, y.length=${yNorm.length}');
        }

        jwk = {
          'crv': 'P-256',
          'ext': true,
          'key_ops': [],
          'kty': 'EC',
          'x': base64Url.encode(xNorm).replaceAll('=', ''),
          'y': base64Url.encode(yNorm).replaceAll('=', ''),
        };
      } else if (key is EcKeyPairData) {
        final xNorm = _normalizeBytes(key.x, 32);
        final yNorm = _normalizeBytes(key.y, 32);

        if (kDebugMode) {
          debugPrint('EncryptionHelper [exportPublicKeyJwk]: EcKeyPairData x.length=${xNorm.length}, y.length=${yNorm.length}');
        }

        jwk = {
          'crv': 'P-256',
          'ext': true,
          'key_ops': [],
          'kty': 'EC',
          'x': base64Url.encode(xNorm).replaceAll('=', ''),
          'y': base64Url.encode(yNorm).replaceAll('=', ''),
        };
      } else if (key is SimplePublicKey) {
        if (key.type == KeyPairType.p256) {
          // Split 64-byte or 65-byte uncompressed EC key into X and Y
          final bytes = key.bytes;
          List<int> x;
          List<int> y;
          if (bytes.length == 64) {
            x = bytes.sublist(0, 32);
            y = bytes.sublist(32);
          } else if (bytes.length == 65 && bytes[0] == 0x04) {
            x = bytes.sublist(1, 33);
            y = bytes.sublist(33, 65);
          } else {
            throw StateError('Expected 64-byte or 65-byte public key for P-256, got ${bytes.length}');
          }

          final xNorm = _normalizeBytes(x, 32);
          final yNorm = _normalizeBytes(y, 32);

          if (kDebugMode) {
            debugPrint('EncryptionHelper [exportPublicKeyJwk]: x.length=${xNorm.length}, y.length=${yNorm.length}');
          }
          
          jwk = {
            'crv': 'P-256',
            'ext': true,
            'key_ops': [],
            'kty': 'EC',
            'x': base64Url.encode(xNorm).replaceAll('=', ''),
            'y': base64Url.encode(yNorm).replaceAll('=', ''),
          };
        } else {
          throw UnsupportedError('Unsupported KeyPairType for JWK export: ${key.type}');
        }
      } else {
        throw UnsupportedError('Unsupported key type for JWK export: ${key.runtimeType}');
      }
      
      return jsonEncode(jwk);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [ENCRYPTION_HELPER] Failed to export public key from $key: $e\n$stack');
      }
      rethrow;
    }
  }

  // Export Public Key to JWK
  static Future<String> exportPublicKey(KeyPair keyPair) async {
    try {
      if (keyPair is EcKeyPairData) {
        return exportPublicKeyJwk(keyPair);
      }
      final publicKey = await keyPair.extractPublicKey();
      return exportPublicKeyJwk(publicKey);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [ENCRYPTION_HELPER] Failed to export public key from keyPair: $e\n$stack');
      }
      rethrow;
    }
  }

  // Import Public Key from JWK
  static Future<PublicKey> importPublicKey(dynamic jwkInput) async {
    try {
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Importing public key. Input type: ${jwkInput.runtimeType}');
      }
      Map<String, dynamic> jwk;
      if (jwkInput is String) {
        jwk = jsonDecode(jwkInput);
      } else if (jwkInput is Map) {
        jwk = Map<String, dynamic>.from(jwkInput);
      } else {
        throw ArgumentError('Invalid JWK format: ${jwkInput.runtimeType}');
      }
      
      final String? crv = jwk['crv'];
      final String? x = jwk['x'];
      final String? y = jwk['y'];

      if (crv == 'P-256') {
        if (x == null || y == null) throw ArgumentError('Missing coordinates for P-256');
        
        final xBytes = _normalizeBytes(base64Url.decode(_padBase64(x)), 32);
        final yBytes = _normalizeBytes(base64Url.decode(_padBase64(y)), 32);
        
        if (kDebugMode) {
          debugPrint('EncryptionHelper [importPublicKey]: x.length=${xBytes.length}, y.length=${yBytes.length}');
        }
        
        // Use EcPublicKey for P-256 compatibility with sharedSecretKey
        return EcPublicKey(x: xBytes, y: yBytes, type: KeyPairType.p256);
      }
      
      throw ArgumentError('Unsupported JWK curve: $crv. Only P-256 is supported.');
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Error importing public key: $e\n$stack');
      }
      rethrow;
    }
  }

  // Derive shared secret
  static Future<SecretKey> deriveSharedSecret(KeyPair myKeyPair, PublicKey partnerPublicKey) async {
    try {
      final myPublicKey = await myKeyPair.extractPublicKey();
      final keyPairData = await myKeyPair.extract();

      if (myPublicKey.type != KeyPairType.p256 || partnerPublicKey.type != KeyPairType.p256) {
        if (kDebugMode) {
          debugPrint('EncryptionHelper ERROR: Key type mismatch. Mine: ${myPublicKey.type.name}, Partner: ${partnerPublicKey.type.name}');
        }
        throw ArgumentError(
          'Key type mismatch or unsupported: Only P-256 is supported. '
          'Mine: ${myPublicKey.type.name}, Partner: ${partnerPublicKey.type.name}'
        );
      }

      if (keyPairData is! EcKeyPairData || partnerPublicKey is! EcPublicKey) {
        if (kDebugMode) {
          debugPrint('EncryptionHelper ERROR: Expected EcKeyPairData and EcPublicKey. Got: ${keyPairData.runtimeType} and ${partnerPublicKey.runtimeType}');
        }
        throw ArgumentError('Expected EcKeyPairData and EcPublicKey for P-256 derivation');
      }

      // CRITICAL: Normalize all coordinates and private scalar d to strictly 32 bytes.
      // iOS FlutterEcdh strictly asserts 32 bytes for P-256: passing 33 bytes throws
      // "Parameter 'd' should have 32 bytes, not 33".
      final normD = _normalizeBytes(keyPairData.d, 32);
      final normMyX = _normalizeBytes(keyPairData.x, 32);
      final normMyY = _normalizeBytes(keyPairData.y, 32);

      final normPartnerX = _normalizeBytes(partnerPublicKey.x, 32);
      final normPartnerY = _normalizeBytes(partnerPublicKey.y, 32);

      if (kDebugMode) {
        debugPrint(
          'EncryptionHelper [deriveSharedSecret]: '
          'd.length=${normD.length}, myX.length=${normMyX.length}, myY.length=${normMyY.length}, '
          'partnerX.length=${normPartnerX.length}, partnerY.length=${normPartnerY.length}',
        );
      }

      final normalizedPartnerKey = EcPublicKey(
        x: normPartnerX,
        y: normPartnerY,
        type: KeyPairType.p256,
      );

      final normalizedMyKey = EcKeyPairData(
        d: normD,
        x: normMyX,
        y: normMyY,
        type: KeyPairType.p256,
      );

      final secretKey = await _p256.sharedSecretKey(
        keyPair: normalizedMyKey,
        remotePublicKey: normalizedPartnerKey,
      );

      // CRITICAL: Normalize the shared secret to exactly 32 bytes.
      // Some ECDH implementations strip leading zeros, but AES-256 requires 256 bits.
      final secretData = await secretKey.extractBytes();
      final normalizedSecret = _normalizeBytes(secretData, 32);
      
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Secret derived successfully. Length: ${normalizedSecret.length}');
      }

      return SecretKey(normalizedSecret);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Shared secret derivation failed: $e\n$stack');
      }
      rethrow;
    }
  }

  /// Derive raw shared secret using exact 32-byte coordinates (standard Web Crypto / iOS CryptoKit ECDH P-256)
  static Future<SecretKey> deriveSharedSecretRaw(KeyPair myKeyPair, PublicKey partnerPublicKey) async {
    try {
      final keyPairData = await myKeyPair.extract();
      if (keyPairData is! EcKeyPairData || partnerPublicKey is! EcPublicKey) {
        throw ArgumentError('Expected EcKeyPairData and EcPublicKey for raw P-256 derivation');
      }

      final normD = _normalizeBytes(keyPairData.d, 32);
      final normMyX = _normalizeBytes(keyPairData.x, 32);
      final normMyY = _normalizeBytes(keyPairData.y, 32);

      final normPartnerX = _normalizeBytes(partnerPublicKey.x, 32);
      final normPartnerY = _normalizeBytes(partnerPublicKey.y, 32);

      if (kDebugMode) {
        debugPrint(
          'EncryptionHelper [deriveSharedSecretRaw]: '
          'd.length=${normD.length}, x.length=${normMyX.length}, y.length=${normMyY.length}, '
          'partnerX.length=${normPartnerX.length}, partnerY.length=${normPartnerY.length}',
        );
      }

      final rawPartnerKey = EcPublicKey(
        x: normPartnerX,
        y: normPartnerY,
        type: KeyPairType.p256,
      );

      final rawMyKey = EcKeyPairData(
        d: normD,
        x: normMyX,
        y: normMyY,
        type: KeyPairType.p256,
      );

      final secretKey = await _p256.sharedSecretKey(
        keyPair: rawMyKey,
        remotePublicKey: rawPartnerKey,
      );

      final secretData = await secretKey.extractBytes();
      return SecretKey(_normalizeBytes(secretData, 32));
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Raw shared secret derivation failed: $e\n$stack');
      }
      rethrow;
    }
  }

  /// Derive shared secret using the LEGACY tweak (for backwards compatibility)
  static Future<SecretKey> deriveSharedSecretLegacy(KeyPair myKeyPair, PublicKey partnerPublicKey) async {
    try {
      final keyPairData = await myKeyPair.extract();
      if (keyPairData is! EcKeyPairData || partnerPublicKey is! EcPublicKey) {
         throw ArgumentError('Expected EcKeyPairData and EcPublicKey for legacy derivation');
      }

      final normD = _normalizeBytes(keyPairData.d, 32);
      final normMyX = _normalizeBytes(keyPairData.x, 32);
      final normMyY = _normalizeBytes(keyPairData.y, 32);

      final normPartnerX = _normalizeBytes(partnerPublicKey.x, 32);
      final normPartnerY = _normalizeBytes(partnerPublicKey.y, 32);

      if (kDebugMode) {
        debugPrint(
          'EncryptionHelper [deriveSharedSecretLegacy]: '
          'd.length=${normD.length}, x.length=${normMyX.length}, y.length=${normMyY.length}',
        );
      }

      SecretKey secretKey;
      try {
        final tweakedPartnerKey = EcPublicKey(
          x: _ensurePositive(normPartnerX),
          y: _ensurePositive(normPartnerY),
          type: KeyPairType.p256,
        );

        final tweakedMyKey = EcKeyPairData(
          d: _ensurePositive(normD),
          x: _ensurePositive(normMyX),
          y: _ensurePositive(normMyY),
          type: KeyPairType.p256,
        );

        secretKey = await _p256.sharedSecretKey(
          keyPair: tweakedMyKey,
          remotePublicKey: tweakedPartnerKey,
        );
      } catch (_) {
        // Fallback to strictly 32-byte keys if platform rejects 33 bytes (e.g. iOS SecKey)
        final fallbackPartnerKey = EcPublicKey(
          x: normPartnerX,
          y: normPartnerY,
          type: KeyPairType.p256,
        );

        final fallbackMyKey = EcKeyPairData(
          d: normD,
          x: normMyX,
          y: normMyY,
          type: KeyPairType.p256,
        );

        secretKey = await _p256.sharedSecretKey(
          keyPair: fallbackMyKey,
          remotePublicKey: fallbackPartnerKey,
        );
      }
      
      final secretData = await secretKey.extractBytes();
      return SecretKey(_normalizeBytes(secretData, 32));
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Legacy shared secret derivation failed: $e\n$stack');
      }
      rethrow;
    }
  }

  /// Derive shared secret using SHA-256 hashing (common in some E2EE implementations)
  static Future<SecretKey> deriveSharedSecretHashed(KeyPair myKeyPair, PublicKey partnerPublicKey) async {
    try {
      final rawSecret = await deriveSharedSecret(myKeyPair, partnerPublicKey);
      final secretBytes = await rawSecret.extractBytes();
      final hash = await Sha256().hash(secretBytes);
      return SecretKey(hash.bytes);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('EncryptionHelper: Hashed shared secret derivation failed: $e\n$stack');
      }
      rethrow;
    }
  }

  // Encrypt message
  static Future<Map<String, String>> encrypt(String text, SecretKey sharedSecret) async {
    try {
      final secretBox = await _aesGcm.encrypt(
        utf8.encode(text),
        secretKey: sharedSecret,
      );
      
      return {
        'text': base64.encode(secretBox.cipherText + secretBox.mac.bytes),
        'iv': base64.encode(secretBox.nonce),
      };
    } catch (e, stack) {
      debugPrint('EncryptionHelper ERROR: Encryption failed: $e');
      debugPrint('EncryptionHelper SecretKey state: ${sharedSecret.hashCode}');
      debugPrint('Stacktrace: $stack');
      return {'text': text, 'iv': ''};
    }
  }

  // Decrypt message
  static Future<String> decrypt(String encryptedBase64, SecretKey sharedSecret, {String? iv}) async {
    if (encryptedBase64.isEmpty) return encryptedBase64;
    
    // Clean up base64 string
    final cleanBase64 = encryptedBase64.trim().replaceAll(RegExp(r'\s+'), '');
    
    if (!_isBase64(cleanBase64)) {
      throw const FormatException('Payload is not valid Base64');
    }
    
    final data = base64.decode(_padBase64(cleanBase64));
    
    SecretBox secretBox;
    if (iv != null && iv.isNotEmpty) {
      final cleanIv = iv.trim().replaceAll(RegExp(r'\s+'), '');
      if (!_isBase64(cleanIv)) {
        throw const FormatException('Provided IV is not valid Base64');
      }
      
      final nonce = base64.decode(_padBase64(cleanIv));
      if (data.length < 16) {
        throw const FormatException('Encrypted data too short for MAC');
      }
      
      final mac = data.sublist(data.length - 16);
      final cipherText = data.sublist(0, data.length - 16);

      secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
    } else {
      // Fallback: Check if IV is prepended (12-byte nonce + cipherText + 16-byte MAC)
      if (data.length < 12 + 16) {
        throw const FormatException('Encrypted data too short for prepended IV');
      }

      final nonce = data.sublist(0, 12);
      final mac = data.sublist(data.length - 16);
      final cipherText = data.sublist(12, data.length - 16);
      
      secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
    }
    
    try {
      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );
      return utf8.decode(decrypted);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [ENCRYPTION_HELPER] AES-GCM Decrypt failed: $e\n$stack');
      }
      rethrow;
    }
  }

  // Load KeyPair from saved private key bytes and public key JWK
  static Future<KeyPair> loadKeyPair(List<int> privateKeyBytes, String publicKeyJwk) async {
    final publicKey = await importPublicKey(publicKeyJwk);
    
    // Normalize private key to 32 bytes
    final normalizedD = _normalizeBytes(privateKeyBytes, 32);

    if (publicKey is EcPublicKey) {
      final normalizedX = _normalizeBytes(publicKey.x, 32);
      final normalizedY = _normalizeBytes(publicKey.y, 32);

      if (kDebugMode) {
        debugPrint('EncryptionHelper [loadKeyPair]: d.length=${normalizedD.length}, x.length=${normalizedX.length}, y.length=${normalizedY.length}');
      }

      if (normalizedD.length != 32 || normalizedX.length != 32 || normalizedY.length != 32) {
        throw StateError('Invalid EC coordinates length for P-256 (expected 32 bytes)');
      }

      return EcKeyPairData(
        d: normalizedD,
        x: normalizedX,
        y: normalizedY,
        type: publicKey.type,
      );
    }

    if (publicKey is! SimplePublicKey) {
      throw StateError('Expected SimplePublicKey or EcPublicKey');
    }

    return SimpleKeyPairData(
      normalizedD,
      publicKey: publicKey,
      type: publicKey.type,
    );
  }

  static bool _isBase64(String str) {
    try {
      final padded = _padBase64(str);
      base64.decode(padded);
      return RegExp(r'^[a-zA-Z0-9+/_-]*={0,2}$').hasMatch(str);
    } catch (_) {
      return false;
    }
  }
}

