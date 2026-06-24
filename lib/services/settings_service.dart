import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class SettingsService {
  static final SettingsService instance = SettingsService._init();
  SettingsService._init();

  Future<File> get _settingsFile async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, 'app_settings.json'));
  }

  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveSetting(String key, dynamic value) async {
    try {
      final file = await _settingsFile;
      final settings = await loadSettings();
      settings[key] = value;
      await file.writeAsString(jsonEncode(settings));
    } catch (_) {}
  }

  Future<String?> getPrimaryDrive() async {
    final settings = await loadSettings();
    return settings['primary_drive'] as String?;
  }

  Future<void> setPrimaryDrive(String path) async {
    await saveSetting('primary_drive', path);
  }

  Future<String?> getBackupDirectory() async {
    final settings = await loadSettings();
    final customDir = settings['backup_directory'] as String?;
    if (customDir != null && customDir.isNotEmpty) {
      return customDir;
    }
    final primaryDrive = settings['primary_drive'] as String?;
    if (primaryDrive != null && primaryDrive.isNotEmpty) {
      return p.join(primaryDrive, 'SecureVault_Backups');
    }
    return null;
  }

  Future<void> setBackupDirectory(String? path) async {
    await saveSetting('backup_directory', path);
  }

  Future<bool> isGoogleDriveEnabled() async {
    final settings = await loadSettings();
    return settings['gdrive_enabled'] as bool? ?? false;
  }

  Future<String?> getGoogleAccount() async {
    final settings = await loadSettings();
    return settings['gdrive_account'] as String?;
  }

  Future<String?> getGoogleName() async {
    final settings = await loadSettings();
    return settings['gdrive_name'] as String?;
  }

  Future<String?> getGoogleDrivePath() async {
    final settings = await loadSettings();
    return settings['gdrive_path'] as String?;
  }

  Future<void> setGoogleDriveConnection({
    required bool enabled,
    String? email,
    String? name,
    String? path,
  }) async {
    await saveSetting('gdrive_enabled', enabled);
    await saveSetting('gdrive_account', email);
    await saveSetting('gdrive_name', name);
    await saveSetting('gdrive_path', path);
  }
}
