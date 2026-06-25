import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionHelper {
  // Pure Dart PBKDF2 implementation using HMAC-SHA256
  static Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final key = Uint8List(keyLength);
    int blockIndex = 1;
    int keyPos = 0;

    while (keyPos < keyLength) {
      final blockIndexBytes = ByteData(4)..setInt32(0, blockIndex, Endian.big);
      final saltAndIndex = Uint8List.fromList([...salt, ...blockIndexBytes.buffer.asUint8List()]);

      var u = hmac.convert(saltAndIndex).bytes;
      var xorSum = Uint8List.fromList(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < xorSum.length; j++) {
          xorSum[j] ^= u[j];
        }
      }

      final bytesToCopy = (keyLength - keyPos) < xorSum.length ? (keyLength - keyPos) : xorSum.length;
      key.setRange(keyPos, keyPos + bytesToCopy, xorSum.sublist(0, bytesToCopy));
      keyPos += bytesToCopy;
      blockIndex++;
    }
    return key;
  }

  // Derive database key from master password using PBKDF2
  static Future<String> deriveDatabaseKey(String masterPassword, String saltBase64) async {
    return await compute(_deriveDatabaseKeyTask, {
      'password': masterPassword,
      'salt': saltBase64,
    });
  }

  static String _deriveDatabaseKeyTask(Map<String, String> params) {
    final password = params['password']!;
    final salt = base64Decode(params['salt']!);
    // Using 50,000 iterations for SQLCipher derivation compatibility and speed balance
    final derived = pbkdf2(utf8.encode(password), salt, 50000, 32);
    return base64Encode(derived);
  }

  // Encrypt data on background Isolate
  static Future<Map<String, String>> encryptData({
    required String passphrase,
    required String plaintext,
  }) async {
    return await compute(_encryptTask, {
      'passphrase': passphrase,
      'plaintext': plaintext,
    });
  }

  static Map<String, String> _encryptTask(Map<String, String> params) {
    final passphrase = params['passphrase']!;
    final plaintext = params['plaintext']!;

    // 1. Generate secure random salt
    final random = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));

    // 2. Derive 256-bit AES key using PBKDF2 (10,000 iterations for backup)
    final keyBytes = pbkdf2(utf8.encode(passphrase), salt, 10000, 32);
    final key = enc.Key(keyBytes);

    // 3. Generate secure random IV
    final iv = enc.IV.fromSecureRandom(16);

    // 4. Encrypt using AES-256-CBC
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return {
      'salt': base64Encode(salt),
      'iv': iv.base64,
      'ciphertext': encrypted.base64,
    };
  }

  // Decrypt data on background Isolate
  static Future<String> decryptData({
    required String passphrase,
    required String ciphertextBase64,
    required String ivBase64,
    String? saltBase64,
  }) async {
    return await compute(_decryptTask, {
      'passphrase': passphrase,
      'ciphertext': ciphertextBase64,
      'iv': ivBase64,
      'salt': saltBase64 ?? '',
    });
  }

  static String _decryptTask(Map<String, String> params) {
    final passphrase = params['passphrase']!;
    final ciphertext = params['ciphertext']!;
    final ivBase64 = params['iv']!;
    final saltBase64 = params['salt']!;

    final iv = enc.IV.fromBase64(ivBase64);
    enc.Key key;

    if (saltBase64.isEmpty) {
      // Version 1 (Legacy backup): SHA-256 key derivation
      final keyBytes = sha256.convert(utf8.encode(passphrase)).bytes;
      key = enc.Key(Uint8List.fromList(keyBytes));
    } else {
      // Version 2 (Secure backup): PBKDF2 key derivation
      final salt = base64Decode(saltBase64);
      final keyBytes = pbkdf2(utf8.encode(passphrase), salt, 10000, 32);
      key = enc.Key(keyBytes);
    }

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(ciphertext, iv: iv);
  }
}
