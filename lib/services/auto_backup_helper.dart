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
  static bool _backupPasswordsScheduled = false;
  static bool _backupDocumentsScheduled = false;

  static Future<void> triggerAutoBackup({bool passwords = false, bool documents = false}) async {
    _backupPasswordsScheduled |= passwords;
    _backupDocumentsScheduled |= documents;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () async {
      final doPasswords = _backupPasswordsScheduled;
      final doDocuments = _backupDocumentsScheduled;
      _backupPasswordsScheduled = false;
      _backupDocumentsScheduled = false;
      await _runAutoBackup(backupPasswords: doPasswords, backupDocuments: doDocuments);
    });
  }

  static Future<void> _runAutoBackup({required bool backupPasswords, required bool backupDocuments}) async {
    if (!backupPasswords && !backupDocuments) return;

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

      debugPrint('Starting silent automatic cloud sync backup (passwords: $backupPasswords, documents: $backupDocuments)...');

      final dbHelper = DatabaseHelper.instance;

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

      final tempDir = await getTemporaryDirectory();

      if (backupPasswords) {
        final passwords = await dbHelper.readAllPasswords();
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

        final pwTemp = File(join(tempDir.path, 'vault_backup.pwm'));
        await pwTemp.writeAsBytes(pwBytes);

        final pwFileName = GDriveService.generateBackupFileName(isPassword: true, isLocal: false);
        await GDriveService.instance.uploadBackupFile(
          localFilePath: pwTemp.path,
          driveFileName: pwFileName,
          folderName: 'Application Backups',
        );

        try {
          await pwTemp.delete();
        } catch (_) {}
      }

      if (backupDocuments) {
        final documents = await dbHelper.readAllDocuments();
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

        final docTemp = File(join(tempDir.path, 'documents_backup.sdm'));
        await docTemp.writeAsBytes(docBytes);

        final docFileName = GDriveService.generateBackupFileName(isPassword: false, isLocal: false);
        await GDriveService.instance.uploadBackupFile(
          localFilePath: docTemp.path,
          driveFileName: docFileName,
          folderName: 'Application Backups',
        );

        try {
          await docTemp.delete();
        } catch (_) {}
      }

      // Prune old backups, keeping only the last 2 backup sets
      await GDriveService.instance.pruneOldBackups();

      debugPrint('Silent automatic cloud sync backup completed successfully.');
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }
}
