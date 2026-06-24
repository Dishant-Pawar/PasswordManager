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
}
