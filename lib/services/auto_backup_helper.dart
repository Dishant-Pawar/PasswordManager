import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart' as crypto;
import 'database_helper.dart';
import 'gdrive_service.dart';
import 'settings_service.dart';

class AutoBackupHelper {
  static Future<void> triggerAutoBackup() async {
    try {
      // 1. Check if auto backup is enabled in settings
      final settings = await SettingsService.instance.loadSettings();
      final autoBackupEnabled = settings['auto_backup_enabled'] as bool? ?? false;
      if (!autoBackupEnabled) {
        debugPrint('Auto backup is disabled in settings.');
        return;
      }

      // 2. Check if signed in to Google Drive
      final isSignedIn = await GDriveService.instance.isSignedIn();
      if (!isSignedIn) {
        debugPrint('Auto backup skipped: Google Drive is not connected.');
        return;
      }

      debugPrint('Starting silent automatic cloud sync backup...');

      // 3. Fetch data from DB
      final dbHelper = DatabaseHelper.instance;
      final passwords = await dbHelper.readAllPasswords();
      final documents = await dbHelper.readAllDocuments();

      // Retrieve the user's custom auto backup passphrase if configured; otherwise use the default secure fallback.
      final customPassphrase = settings['auto_backup_passphrase'] as String?;
      final passphrase = (customPassphrase != null && customPassphrase.trim().isNotEmpty)
          ? customPassphrase.trim()
          : 'SecureVaultAutoBackupPassphraseKey123!';

      // Encryption logic for passwords
      final List<Map<String, dynamic>> passwordMaps = passwords.map((p) => p.toMap()).toList();
      final pwJsonString = jsonEncode(passwordMaps);
      
      final keyBytes = crypto.sha256.convert(utf8.encode(passphrase)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      
      final pwIv = enc.IV.fromSecureRandom(16);
      final pwEncrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final pwEncrypted = pwEncrypter.encrypt(pwJsonString, iv: pwIv);
      
      final pwBackupPayload = {
        'version': 1,
        'iv': pwIv.base64,
        'ciphertext': pwEncrypted.base64,
      };
      final pwBackupString = jsonEncode(pwBackupPayload);
      final pwBytes = Uint8List.fromList(utf8.encode(pwBackupString));

      // Encryption logic for documents
      final List<Map<String, dynamic>> docMaps = [];
      for (final doc in documents) {
        if (doc.filePath.isNotEmpty) {
          final file = File(doc.filePath);
          if (await file.exists()) {
            final fileBytes = await file.readAsBytes();
            docMaps.add({
              'name': doc.name,
              'fileType': doc.fileType,
              'sizeBytes': doc.sizeBytes,
              'createdAt': doc.createdAt.toIso8601String(),
              'fileContentBase64': base64Encode(fileBytes),
            });
          }
        }
      }
      final docJsonString = jsonEncode(docMaps);
      final docIv = enc.IV.fromSecureRandom(16);
      final docEncrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final docEncrypted = docEncrypter.encrypt(docJsonString, iv: docIv);
      
      final docBackupPayload = {
        'version': 1,
        'iv': docIv.base64,
        'ciphertext': docEncrypted.base64,
      };
      final docBackupString = jsonEncode(docBackupPayload);
      final docBytes = Uint8List.fromList(utf8.encode(docBackupString));

      final now = DateTime.now();
      final folderName = 'backup_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';

      // Save temp files locally to upload them
      final tempDir = await getTemporaryDirectory();
      final pwTemp = File(join(tempDir.path, 'vault_backup.pwm'));
      await pwTemp.writeAsBytes(pwBytes);

      final docTemp = File(join(tempDir.path, 'documents_backup.sdm'));
      await docTemp.writeAsBytes(docBytes);

      // Upload to real Drive
      await GDriveService.instance.uploadBackupFile(
        localFilePath: pwTemp.path,
        driveFileName: '${folderName}_vault.pwm',
        folderName: 'Application Backups',
      );

      await GDriveService.instance.uploadBackupFile(
        localFilePath: docTemp.path,
        driveFileName: '${folderName}_documents.sdm',
        folderName: 'Application Backups',
      );

      // Clean temp files
      try {
        await pwTemp.delete();
        await docTemp.delete();
      } catch (_) {}

      debugPrint('Silent automatic cloud sync backup completed successfully.');
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
