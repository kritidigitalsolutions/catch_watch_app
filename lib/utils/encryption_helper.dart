import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EncryptionHelper {
  // Use P-256 for standard E2EE compatibility
  static final _p256 = Ecdh.p256(length: 32);
  static final AesGcm _aesGcm = AesGcm.with256bits();

  // Generate a new key pair
  static Future<KeyPair> generateKeyPair() async {
    try {
      debugPrint('EncryptionHelper: Generating new P-256 KeyPair...');
      final keyPair = await _p256.newKeyPair();
      debugPrint('EncryptionHelper: KeyPair generated successfully');
      return keyPair;
    } catch (e) {
      debugPrint('EncryptionHelper: Error generating KeyPair: $e');
      rethrow;
    }
  }

  // Export Public Key to JWK
  static Future<String> exportPublicKey(KeyPair keyPair) async {
    try {
      final publicKey = await keyPair.extractPublicKey();
      
      Map<String, dynamic> jwk;
      
      if (publicKey is EcPublicKey) {
        jwk = {
          'crv': 'P-256',
          'ext': true,
          'key_ops': [],
          'kty': 'EC',
          'x': base64Url.encode(_normalizeBytes(Uint8List.fromList(publicKey.x), 32)).replaceAll('=', ''),
          'y': base64Url.encode(_normalizeBytes(Uint8List.fromList(publicKey.y), 32)).replaceAll('=', ''),
        };
      } else if (publicKey is SimplePublicKey) {
        if (publicKey.type == KeyPairType.p256) {
          // Split 64-byte uncompressed EC key into X and Y
          final bytes = publicKey.bytes;
          if (bytes.length != 64) {
            throw StateError('Expected 64-byte public key for P-256, got ${bytes.length}');
          }
          final x = bytes.sublist(0, 32);
          final y = bytes.sublist(32);
          
          jwk = {
            'crv': 'P-256',
            'ext': true,
            'key_ops': [],
            'kty': 'EC',
            'x': base64Url.encode(_normalizeBytes(Uint8List.fromList(x), 32)).replaceAll('=', ''),
            'y': base64Url.encode(_normalizeBytes(Uint8List.fromList(y), 32)).replaceAll('=', ''),
          };
        } else {
          throw UnsupportedError('Unsupported KeyPairType for JWK export: ${publicKey.type}');
        }
      } else {
        throw UnsupportedError('Unsupported PublicKey type: ${publicKey.runtimeType}');
      }
      
      return jsonEncode(jwk);
    } catch (e) {
      debugPrint('EncryptionHelper: Failed to export public key: $e');
      rethrow;
    }
  }

  // Import Public Key from JWK
  static Future<PublicKey> importPublicKey(dynamic jwkInput) async {
    try {
      debugPrint('EncryptionHelper: Importing public key. Input type: ${jwkInput.runtimeType}');
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

      debugPrint('EncryptionHelper: JWK details - crv: $crv, hasX: ${x != null}, hasY: ${y != null}');

      if (crv == 'P-256') {
        if (x == null || y == null) throw ArgumentError('Missing coordinates for P-256');
        
        final xBytes = _normalizeBytes(base64Url.decode(_padBase64(x)), 32);
        final yBytes = _normalizeBytes(base64Url.decode(_padBase64(y)), 32);
        
        debugPrint('EncryptionHelper: P-256 coordinates normalized (32 bytes each)');
        debugPrint('EncryptionHelper: Partner X-prefix: ${xBytes.sublist(0, 4)}');
        
        // Use EcPublicKey for P-256 compatibility with sharedSecretKey
        return EcPublicKey(x: xBytes, y: yBytes, type: KeyPairType.p256);
      }
      
      throw ArgumentError('Unsupported JWK curve: $crv. Only P-256 is supported.');
    } catch (e) {
      debugPrint('EncryptionHelper: Error importing public key: $e');
      rethrow;
    }
  }

  static Uint8List _normalizeBytes(List<int> bytes, int length) {
    if (bytes.length == length) return Uint8List.fromList(bytes);
    if (bytes.length > length) {
      // Remove leading zeros if present
      int start = 0;
      while (start < bytes.length - length && bytes[start] == 0) {
        start++;
      }
      final result = bytes.sublist(start);
      if (result.length > length) {
        // Still too long? Take the last 'length' bytes
        return Uint8List.fromList(result.sublist(result.length - length));
      }
      // If shorter, it will be handled by padding below
      bytes = result;
    }
    
    // Pad with leading zeros
    final padded = Uint8List(length);
    padded.setRange(length - bytes.length, length, bytes);
    return padded;
  }

  static String _padBase64(String input) {
    int length = input.length;
    int mod = length % 4;
    if (mod == 0) return input;
    return input.padRight(length + (4 - mod), '=');
  }

  /// Ensures a byte array is interpreted as positive by prepending a 0x00 byte
  /// if the most significant bit is set. (Legacy fallback for older app versions)
  static List<int> _ensurePositive(List<int> bytes) {
    if (bytes.isEmpty) return bytes;
    if (bytes[0] >= 128) {
      return [0, ...bytes];
    }
    return bytes;
  }

  // Derive shared secret
  static Future<SecretKey> deriveSharedSecret(KeyPair myKeyPair, PublicKey partnerPublicKey) async {
    try {
      final myPublicKey = await myKeyPair.extractPublicKey();
      final keyPairData = await myKeyPair.extract();

      debugPrint('EncryptionHelper: myKeyPair type = ${myPublicKey.type.name}, remotePublicKey type = ${partnerPublicKey.type.name}');

      if (myPublicKey.type != KeyPairType.p256 || partnerPublicKey.type != KeyPairType.p256) {
        throw ArgumentError(
          'Key type mismatch or unsupported: Only P-256 is supported. '
          'Mine: ${myPublicKey.type.name}, Partner: ${partnerPublicKey.type.name}'
        );
      }

      if (keyPairData is! EcKeyPairData || partnerPublicKey is! EcPublicKey) {
         throw ArgumentError('Expected EcKeyPairData and EcPublicKey for P-256 derivation');
      }

      debugPrint('EncryptionHelper: Deriving P-256 secret...');
      debugPrint('EncryptionHelper: My X (len ${keyPairData.x.length}): ${base64.encode(keyPairData.x.sublist(0, 4))}...');
      debugPrint('EncryptionHelper: Partner X (len ${partnerPublicKey.x.length}): ${base64.encode(partnerPublicKey.x.sublist(0, 4))}...');
      
      final secretKey = await _p256.sharedSecretKey(
        keyPair: keyPairData,
        remotePublicKey: partnerPublicKey,
      );

      // CRITICAL: Normalize the shared secret to exactly 32 bytes.
      // Some ECDH implementations strip leading zeros, but AES-256 requires 256 bits.
      final secretData = await secretKey.extractBytes();
      final normalizedSecret = _normalizeBytes(secretData, 32);
      
      final fingerprint = base64.encode(normalizedSecret.sublist(0, 8));
      debugPrint('EncryptionHelper: Secret derived. Length: ${normalizedSecret.length}, Fingerprint: $fingerprint');

      return SecretKey(normalizedSecret);
    } catch (e) {
      debugPrint('EncryptionHelper: Shared secret derivation failed: $e');
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

      final tweakedPartnerKey = EcPublicKey(
        x: _ensurePositive(partnerPublicKey.x),
        y: _ensurePositive(partnerPublicKey.y),
        type: KeyPairType.p256,
      );

      final tweakedMyKey = EcKeyPairData(
        d: _ensurePositive(keyPairData.d),
        x: _ensurePositive(keyPairData.x),
        y: _ensurePositive(keyPairData.y),
        type: KeyPairType.p256,
      );

      final secretKey = await _p256.sharedSecretKey(
        keyPair: tweakedMyKey,
        remotePublicKey: tweakedPartnerKey,
      );
      
      final secretData = await secretKey.extractBytes();
      return SecretKey(_normalizeBytes(secretData, 32));
    } catch (e) {
      debugPrint('EncryptionHelper: Legacy shared secret derivation failed: $e');
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
    } catch (e) {
      debugPrint('EncryptionHelper: Hashed shared secret derivation failed: $e');
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
      debugPrint('EncryptionHelper: Encryption failed: $e');
      debugPrint('Stacktrace: $stack');
      return {'text': text, 'iv': ''};
    }
  }

  // Decrypt message
  static Future<String> decrypt(String encryptedBase64, SecretKey sharedSecret, {String? iv}) async {
    if (encryptedBase64.isEmpty) return encryptedBase64;
    
    try {
      // Clean up base64 string (sometimes received with spaces or wrong padding from different sources)
      final cleanBase64 = encryptedBase64.trim().replaceAll(RegExp(r'\s+'), '');
      
      if (!_isBase64(cleanBase64)) {
        debugPrint('EncryptionHelper: Not a valid Base64 string, returning as-is');
        return cleanBase64;
      }
      
      final data = base64.decode(_padBase64(cleanBase64));
      debugPrint('EncryptionHelper: Decrypting ${data.length} bytes total');
      
      SecretBox secretBox;
      if (iv != null && iv.isNotEmpty) {
        final cleanIv = iv.trim().replaceAll(RegExp(r'\s+'), '');
        if (!_isBase64(cleanIv)) {
          debugPrint('EncryptionHelper: Provided IV is not valid Base64');
          return cleanBase64;
        }
        
        final nonce = base64.decode(_padBase64(cleanIv));
        if (data.length < 16) {
           debugPrint('EncryptionHelper: Encrypted data too short (needs at least 16 bytes for MAC)');
           return cleanBase64;
        }
        
        final mac = data.sublist(data.length - 16);
        final cipherText = data.sublist(0, data.length - 16);
        
        debugPrint('EncryptionHelper: IV (len ${nonce.length}): ${base64.encode(nonce)}');
        debugPrint('EncryptionHelper: MAC (len ${mac.length}): ${base64.encode(mac)}');
        debugPrint('EncryptionHelper: CipherText len: ${cipherText.length}');

        secretBox = SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(mac),
        );
      } else {
        // Fallback: Check if IV is prepended (standard for some libraries)
        if (data.length < 12 + 16) {
          debugPrint('EncryptionHelper: Encrypted data too short for prepended IV format');
          return cleanBase64;
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
      
      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );
      return utf8.decode(decrypted);
    } on SecretBoxAuthenticationError {
      // Rethrow MAC errors so the Provider can handle cache recovery
      rethrow;
    } catch (e) {
      debugPrint('EncryptionHelper: Decryption failed: $e');
      return encryptedBase64; 
    }
  }

  // Load KeyPair from saved private key bytes and public key JWK
  static Future<KeyPair> loadKeyPair(List<int> privateKeyBytes, String publicKeyJwk) async {
    final publicKey = await importPublicKey(publicKeyJwk);
    
    // Normalize private key to 32 bytes
    final normalizedD = _normalizeBytes(privateKeyBytes, 32);

    if (publicKey is EcPublicKey) {
      return EcKeyPairData(
        d: normalizedD,
        x: publicKey.x,
        y: publicKey.y,
        type: publicKey.type,
      );
    }

    if (publicKey is! SimplePublicKey) {
      throw StateError('Expected SimplePublicKey or EcPublicKey');
    }

    return SimpleKeyPairData(
      privateKeyBytes,
      publicKey: publicKey,
      type: publicKey.type,
    );
  }

  static bool _isBase64(String str) {
    try {
      base64.decode(str);
      return str.length % 4 == 0 && RegExp(r'^[a-zA-Z0-9+/]*={0,2}$').hasMatch(str);
    } catch (_) {
      return false;
    }
  }
}
