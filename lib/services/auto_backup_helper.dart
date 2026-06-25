import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'encryption_helper.dart';
import 'gdrive_service.dart';
import 'settings_service.dart';

class AutoBackupHelper {
  static Timer? _debounceTimer;

  static Future<void> triggerAutoBackup() async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () async {
      await _runAutoBackup();
    });
  }

  static Future<void> _runAutoBackup() async {
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

      // Retrieve backup passphrase (custom or fallback to database password)
      final customPassphrase = settings['auto_backup_passphrase'] as String?;
      String? passphrase;
      if (customPassphrase != null && customPassphrase.trim().isNotEmpty) {
        passphrase = customPassphrase.trim();
      } else {
        passphrase = DatabaseHelper.databasePassword;
      }

      if (passphrase == null) {
        debugPrint('Auto backup skipped: No passphrase or database password is available.');
        return;
      }

      // Encryption logic for passwords off-thread
      final List<Map<String, dynamic>> passwordMaps = passwords.map((p) => p.toMap()).toList();
      final pwJsonString = jsonEncode(passwordMaps);

      final pwEncryptedResult = await EncryptionHelper.encryptData(
        passphrase: passphrase,
        plaintext: pwJsonString,
      );

      final pwBackupPayload = {
        'version': 2,
        'salt': pwEncryptedResult['salt']!,
        'iv': pwEncryptedResult['iv']!,
        'ciphertext': pwEncryptedResult['ciphertext']!,
      };
      final pwBackupString = jsonEncode(pwBackupPayload);
      final pwBytes = Uint8List.fromList(utf8.encode(pwBackupString));

      // Encryption logic for documents off-thread
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

      final docEncryptedResult = await EncryptionHelper.encryptData(
        passphrase: passphrase,
        plaintext: docJsonString,
      );

      final docBackupPayload = {
        'version': 2,
        'salt': docEncryptedResult['salt']!,
        'iv': docEncryptedResult['iv']!,
        'ciphertext': docEncryptedResult['ciphertext']!,
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
