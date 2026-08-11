import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class EncryptionHelper {
  // Use a more explicit way to ensure implementation availability
  static final Ecdh _ecdh = Ecdh.p256(length: 32);
  static final AesGcm _aesGcm = AesGcm.with256bits();

  // Generate a new key pair
  static Future<EcKeyPair> generateKeyPair() async {
    try {
      debugPrint('EncryptionHelper: Generating new KeyPair...');
      final keyPair = await _ecdh.newKeyPair();
      debugPrint('EncryptionHelper: KeyPair generated successfully');
      return keyPair;
    } catch (e) {
      debugPrint('EncryptionHelper: Error generating KeyPair: $e');
      rethrow;
    }
  }

  // Export Public Key to JWK
  static Future<String> exportPublicKey(EcKeyPair keyPair) async {
    try {
      final publicKey = await keyPair.extractPublicKey();
      
      final jwk = {
        'kty': 'EC',
        'crv': 'P-256',
        'x': base64Url.encode(publicKey.x).replaceAll('=', ''),
        'y': base64Url.encode(publicKey.y).replaceAll('=', ''),
      };
      
      return jsonEncode(jwk);
    } catch (e) {
      print('EncryptionHelper: Failed to export public key: $e');
      rethrow;
    }
  }

  // Import Public Key from JWK
  static EcPublicKey importPublicKey(String jwkString) {
    final jwk = jsonDecode(jwkString);
    return EcPublicKey(
      x: base64Url.decode(_padBase64(jwk['x'])),
      y: base64Url.decode(_padBase64(jwk['y'])),
      type: KeyPairType.p256,
    );
  }

  static String _padBase64(String input) {
    int length = input.length;
    int mod = length % 4;
    if (mod == 0) return input;
    return input.padRight(length + (4 - mod), '=');
  }

  // Derive shared secret
  static Future<SecretKey> deriveSharedSecret(EcKeyPair myKeyPair, EcPublicKey partnerPublicKey) async {
    return await _ecdh.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: partnerPublicKey,
    );
  }

  // Encrypt message
  static Future<String> encrypt(String text, SecretKey sharedSecret) async {
    try {
      final secretBox = await _aesGcm.encrypt(
        utf8.encode(text),
        secretKey: sharedSecret,
      );
      // Combine nonce + cipherText + mac
      final combined = Uint8List.fromList([
        ...secretBox.nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);
      return base64.encode(combined);
    } catch (e, stack) {
      debugPrint('EncryptionHelper: Encryption failed: $e');
      debugPrint('Stacktrace: $stack');
      return text;
    }
  }

  // Decrypt message
  static Future<String> decrypt(String encryptedBase64, SecretKey sharedSecret) async {
    if (!_isBase64(encryptedBase64)) return encryptedBase64;
    
    try {
      final data = base64.decode(encryptedBase64);

      
      // Nonce is 12 bytes for AES-GCM, MAC is 16 bytes
      if (data.length < 12 + 16) return encryptedBase64; // Not encrypted or malformed

      final nonce = data.sublist(0, 12);
      final mac = data.sublist(data.length - 16);
      final cipherText = data.sublist(12, data.length - 16);
      
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
      
      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );
      return utf8.decode(decrypted);
    } catch (e) {
      // If decryption fails, it might not be encrypted or we have wrong key
      return encryptedBase64; 
    }
  }

  // Load KeyPair from saved private key bytes and public key JWK
  static Future<EcKeyPair> loadKeyPair(List<int> privateKeyBytes, String publicKeyJwk) async {
    final publicKey = importPublicKey(publicKeyJwk);
    return EcKeyPairData(
      d: privateKeyBytes,
      x: publicKey.x,
      y: publicKey.y,
      type: KeyPairType.p256,
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

