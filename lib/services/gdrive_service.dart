import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GDriveService {
  static final GDriveService instance = GDriveService._init();
  GDriveService._init();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  Future<GoogleSignInAccount?> get currentUser async {
    if (_currentUser == null) {
      _currentUser = _googleSignIn.currentUser;
      if (_currentUser == null) {
        try {
          _currentUser = await _googleSignIn.signInSilently();
        } catch (_) {}
      }
      if (_currentUser != null) {
        final client = await _googleSignIn.authenticatedClient();
        if (client != null) {
          _driveApi = drive.DriveApi(client);
        }
      }
    }
    return _currentUser;
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      // Force account chooser by signing out first
      await signOut();
      
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        final client = await _googleSignIn.authenticatedClient();
        if (client != null) {
          _driveApi = drive.DriveApi(client);
        }
      }
      return _currentUser;
    } catch (e) {
      debugPrint("Google Sign In error: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _driveApi = null;
    } catch (_) {}
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Fetch storage quota (total, used, remaining) in bytes
  Future<Map<String, int>> getStorageQuota() async {
    await currentUser;
    if (_driveApi == null) throw Exception("Google Drive Client is not authenticated.");

    final about = await _driveApi!.about.get($fields: 'storageQuota');
    final quota = about.storageQuota;
    
    if (quota == null) {
      return {'total': 0, 'used': 0, 'remaining': 0};
    }

    final limit = int.tryParse(quota.limit ?? '0') ?? 0;
    final usage = int.tryParse(quota.usage ?? '0') ?? 0;
    final remaining = limit - usage;

    return {
      'total': limit,
      'used': usage,
      'remaining': remaining > 0 ? remaining : 0,
    };
  }

  // Find or create folder in Google Drive
  Future<String> _getOrCreateFolder(String name) async {
    if (_driveApi == null) throw Exception("Google Drive Client is not authenticated.");

    // Search for folder by name
    final query = "mimeType = 'application/vnd.google-apps.folder' and name = '$name' and trashed = false";
    final fileList = await _driveApi!.files.list(q: query, $fields: 'files(id, name)');
    
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id!;
    }

    // Not found, create it
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await _driveApi!.files.create(folder, $fields: 'id');
    return createdFolder.id!;
  }

  // Upload file to the dedicated folder
  Future<drive.File> uploadBackupFile({
    required String localFilePath,
    required String driveFileName,
    String folderName = "Application Backups",
  }) async {
    await currentUser;
    if (_driveApi == null) throw Exception("Google Drive Client is not authenticated.");

    final folderId = await _getOrCreateFolder(folderName);

    final localFile = File(localFilePath);
    if (!await localFile.exists()) {
      throw Exception("Local backup file not found at $localFilePath");
    }

    final mediaStream = localFile.openRead();
    final mediaStreamLength = await localFile.length();
    final uploadMedia = drive.Media(mediaStream, mediaStreamLength);

    final fileMetadata = drive.File()
      ..name = driveFileName
      ..parents = [folderId];

    return await _driveApi!.files.create(
      fileMetadata,
      uploadMedia: uploadMedia,
      $fields: 'id, name, size, createdTime',
    );
  }

  // Fetch file list in history
  Future<List<drive.File>> getBackupHistory({
    String folderName = "Application Backups",
  }) async {
    await currentUser;
    if (_driveApi == null) return [];

    try {
      final folderId = await _getOrCreateFolder(folderName);
      final query = "'$folderId' in parents and trashed = false";
      final fileList = await _driveApi!.files.list(
        q: query,
        orderBy: 'createdTime desc',
        $fields: 'files(id, name, size, createdTime)',
      );
      return fileList.files ?? [];
    } catch (_) {
      return [];
    }
  }

  // Upload raw bytes directly to the dedicated folder on Google Drive
  Future<drive.File> uploadFileBytes({
    required List<int> bytes,
    required String driveFileName,
    String folderName = "Application Backups",
  }) async {
    await currentUser;
    if (_driveApi == null) throw Exception("Google Drive Client is not authenticated.");

    final folderId = await _getOrCreateFolder(folderName);

    final mediaStream = Stream.value(bytes);
    final uploadMedia = drive.Media(mediaStream, bytes.length);

    final fileMetadata = drive.File()
      ..name = driveFileName
      ..parents = [folderId];

    return await _driveApi!.files.create(
      fileMetadata,
      uploadMedia: uploadMedia,
      $fields: 'id, name, size, createdTime',
    );
  }

  // Download a file's media bytes from Google Drive using its fileId
  Future<List<int>> downloadFile(String fileId) async {
    await currentUser;
    if (_driveApi == null) throw Exception("Google Drive Client is not authenticated.");

    final response = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (response is drive.Media) {
      final List<int> bytes = [];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }
      return bytes;
    } else {
      throw Exception("Failed to download file media.");
    }
  }

  // Delete a file from Google Drive using its fileId
  Future<void> deleteFile(String fileId) async {
    await currentUser;
    if (_driveApi == null) throw Exception("Google Drive Client is not authenticated.");
    await _driveApi!.files.delete(fileId);
  }

  // Generate backup prefix formatted as backup_Day_YYYY-MM-DD_HH-MM-SS
  static String generateBackupPrefix() {
    final now = DateTime.now();
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = dayNames[now.weekday - 1];
    
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    
    return 'backup_${dayName}_$year-$month-${day}_$hour-$minute-$second';
  }

  // Generate the new customized backup file names:
  // e.g. Pass-B monday_25/06/26_.pwm (for drive) or Pass-B monday_25-06-26_.pwm (for local)
  static String generateBackupFileName({required bool isPassword, required bool isLocal}) {
    final now = DateTime.now();
    final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayName = dayNames[now.weekday - 1];
    
    final yearShort = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    
    final typePrefix = isPassword ? 'Pass-B' : 'Doc-B';
    final dateStr = isLocal ? '$day-$month-$yearShort' : '$day/$month/$yearShort';
    final extension = isPassword ? '.pwm' : '.sdm';
    
    return '$typePrefix ${dayName}_${dateStr}_$extension';
  }

  // Prune old backups, keeping only the last 2 backup sets (pairs of pwm/sdm) on Google Drive
  Future<void> pruneOldBackups({String folderName = "Application Backups"}) async {
    await currentUser;
    if (_driveApi == null) return;

    try {
      final folderId = await _getOrCreateFolder(folderName);
      final query = "'$folderId' in parents and trashed = false";
      final fileList = await _driveApi!.files.list(
        q: query,
        $fields: 'files(id, name, size, createdTime)',
      );
      
      final files = fileList.files;
      if (files == null || files.isEmpty) return;

      // Group files by backup prefix
      final Map<String, List<drive.File>> backups = {};

      for (final file in files) {
        final name = file.name;
        if (name == null) continue;

        String? prefix;
        if (name.endsWith('_vault.pwm')) {
          prefix = name.substring(0, name.length - '_vault.pwm'.length);
        } else if (name.endsWith('_documents.sdm')) {
          prefix = name.substring(0, name.length - '_documents.sdm'.length);
        } else if (name.startsWith('Pass-B ') && name.endsWith('.pwm')) {
          prefix = name.substring('Pass-B '.length, name.length - '.pwm'.length);
        } else if (name.startsWith('Doc-B ') && name.endsWith('.sdm')) {
          prefix = name.substring('Doc-B '.length, name.length - '.sdm'.length);
        }

        if (prefix != null) {
          if (!backups.containsKey(prefix)) {
            backups[prefix] = [];
          }
          backups[prefix]!.add(file);
        }
      }

      if (backups.length <= 2) return;

      // For each backup group, determine its timestamp using file createdTime metadata
      final List<MapEntry<String, DateTime>> backupTimes = [];
      for (final entry in backups.entries) {
        DateTime? latestTime;
        for (final file in entry.value) {
          if (file.createdTime != null) {
            if (latestTime == null || file.createdTime!.isAfter(latestTime)) {
              latestTime = file.createdTime;
            }
          }
        }
        backupTimes.add(MapEntry(entry.key, latestTime ?? DateTime.now()));
      }

      // Sort backup groups descending by createdTime (newest first)
      backupTimes.sort((a, b) => b.value.compareTo(a.value));

      // Keep index 0 and 1, delete index >= 2
      for (int i = 2; i < backupTimes.length; i++) {
        final prefixToDelete = backupTimes[i].key;
        final filesToDelete = backups[prefixToDelete]!;
        for (final file in filesToDelete) {
          if (file.id != null) {
            try {
              await deleteFile(file.id!);
              debugPrint('Deleted old backup file: ${file.name}');
            } catch (e) {
              debugPrint('Failed to delete old backup file ${file.name}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error pruning old backups: $e');
    }
  }
}
