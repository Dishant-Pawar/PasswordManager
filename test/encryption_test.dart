import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart' as crypto;
import 'package:passwordmaster/models/password_item.dart';

void main() {
  group('Password Serialization & Encryption Tests', () {
    test('PasswordItem should serialize and deserialize correctly', () {
      final item = PasswordItem(
        id: 42,
        title: 'Google',
        username: 'test@gmail.com',
        password: 'securePassword123',
        url: 'https://google.com',
        notes: 'Some notes here',
        category: 'Work',
        createdAt: DateTime(2026, 6, 24, 12, 0, 0),
        updatedAt: DateTime(2026, 6, 24, 12, 30, 0),
      );

      final map = item.toMap();
      expect(map['id'], 42);
      expect(map['title'], 'Google');
      expect(map['username'], 'test@gmail.com');
      expect(map['password'], 'securePassword123');
      expect(map['url'], 'https://google.com');
      expect(map['notes'], 'Some notes here');
      expect(map['category'], 'Work');
      expect(map['createdAt'], item.createdAt.toIso8601String());
      expect(map['updatedAt'], item.updatedAt.toIso8601String());

      final restored = PasswordItem.fromMap(map);
      expect(restored.id, 42);
      expect(restored.title, 'Google');
      expect(restored.username, 'test@gmail.com');
      expect(restored.password, 'securePassword123');
      expect(restored.url, 'https://google.com');
      expect(restored.notes, 'Some notes here');
      expect(restored.category, 'Work');
      expect(restored.createdAt, item.createdAt);
      expect(restored.updatedAt, item.updatedAt);
    });

    test('AES Encryption and Decryption with Derived Key works', () {
      final passwords = [
        PasswordItem(title: 'Google', username: 'john', password: 'pwd1', category: 'General'),
        PasswordItem(title: 'GitHub', username: 'johndoe', password: 'pwd2', category: 'General'),
      ];

      final passphrase = 'mySecretPassphrase!';
      
      // 1. Serialize to JSON
      final jsonString = jsonEncode(passwords.map((p) => p.toMap()).toList());

      // 2. Derive key using SHA-256
      final keyBytes = crypto.sha256.convert(utf8.encode(passphrase)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));

      // 3. Encrypt
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(jsonString, iv: iv);

      // 4. Decrypt
      final decryptedString = encrypter.decrypt(encrypted, iv: iv);

      // 5. Deserialize
      final List<dynamic> decodedList = jsonDecode(decryptedString);
      final restored = decodedList.map((m) => PasswordItem.fromMap(m)).toList();

      expect(restored.length, 2);
      expect(restored[0].title, 'Google');
      expect(restored[0].username, 'john');
      expect(restored[0].password, 'pwd1');
      expect(restored[1].title, 'GitHub');
      expect(restored[1].username, 'johndoe');
      expect(restored[1].password, 'pwd2');
    });

    test('AES Decryption throws or fails with incorrect key/passphrase', () {
      final originalData = 'secret data';
      final passphrase = 'correctPassphrase';
      final wrongPassphrase = 'wrongPassphrase';

      final keyBytes = crypto.sha256.convert(utf8.encode(passphrase)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));

      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(originalData, iv: iv);

      // Try decrypting with wrong key
      final wrongKeyBytes = crypto.sha256.convert(utf8.encode(wrongPassphrase)).bytes;
      final wrongKey = enc.Key(Uint8List.fromList(wrongKeyBytes));
      final wrongEncrypter = enc.Encrypter(enc.AES(wrongKey, mode: enc.AESMode.cbc));

      expect(() => wrongEncrypter.decrypt(encrypted, iv: iv), throwsA(anything));
    });
  });
}
