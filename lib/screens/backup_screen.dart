// ignore_for_file: unused_element, unused_field
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:sqflite/sqflite.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/settings_service.dart';
import '../services/database_helper.dart';
import '../services/gdrive_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _primaryDrive;
  String? _backupDirectory;
  List<Map<String, String>> _availableDrives = [];
  bool _loading = true;
  bool _isValidating = false;
  String? _validatingDrivePath;
  bool _isBackingUp = false;

  // Google Drive states
  bool _gdriveEnabled = false;
  String? _gdriveAccount;
  String? _gdriveName;
  String? _gdrivePath;
  String? _gdrivePhoto;
  
  // Storage usage stats
  int _gdriveTotalSpace = 0;
  int _gdriveUsedSpace = 0;
  bool _gdriveCloudSyncConnected = false;

  // Automatic Backup State
  bool _autoBackupEnabled = false;

  // Backup History list
  List<drive.File> _backupHistory = [];
  bool _loadingHistory = false;

  final _passphraseCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  double get _strength {
    final v = _passphraseCtrl.text;
    double s = 0;
    if (v.length >= 8) s += 0.25;
    if (v.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (v.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (v.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.25;
    return s;
  }

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBackupSettings() async {
    setState(() => _loading = true);
    
    // Load persisted settings
    final drive = await SettingsService.instance.getPrimaryDrive();
    final backupDir = await SettingsService.instance.getBackupDirectory();
    final gdrive = await SettingsService.instance.isGoogleDriveEnabled();
    final gaccount = await SettingsService.instance.getGoogleAccount();
    final gname = await SettingsService.instance.getGoogleName();
    final gpath = await SettingsService.instance.getGoogleDrivePath();
    final gphoto = await SettingsService.instance.getGooglePhoto();
    final settings = await SettingsService.instance.loadSettings();
    final autoBackup = settings['auto_backup_enabled'] as bool? ?? false;
    
    // Detect available drives
    final drives = await _detectDrives();

    // Check Google Drive API sign-in status
    bool isCloudConnected = false;
    if (gdrive && gpath == null) {
      try {
        isCloudConnected = await GDriveService.instance.isSignedIn();
        // Try silent/current user sign in to populate GDriveService client if signed in
        if (isCloudConnected) {
          final account = await GDriveService.instance.currentUser;
          if (account == null) {
            isCloudConnected = false;
          }
        }
      } catch (_) {}
    }

    setState(() {
      _primaryDrive = drive;
      _backupDirectory = backupDir;
      _gdriveEnabled = gdrive;
      _gdriveAccount = gaccount;
      _gdriveName = gname;
      _gdrivePath = gpath;
      _gdrivePhoto = gphoto;
      _autoBackupEnabled = autoBackup;
      _availableDrives = drives;
      _gdriveCloudSyncConnected = isCloudConnected;
      _loading = false;
    });

    if (isCloudConnected) {
      _fetchGDriveMetadata();
    }
  }

  Future<void> _fetchGDriveMetadata() async {
    setState(() => _loadingHistory = true);
    try {
      final quota = await GDriveService.instance.getStorageQuota();
      final history = await GDriveService.instance.getBackupHistory();
      
      setState(() {
        _gdriveTotalSpace = quota['total'] ?? 0;
        _gdriveUsedSpace = quota['used'] ?? 0;
        _backupHistory = history;
        _loadingHistory = false;
      });
    } catch (_) {
      setState(() => _loadingHistory = false);
    }
  }

  Future<List<Map<String, String>>> _detectDrives() async {
    List<Map<String, String>> drives = [];
    if (Platform.isWindows) {
      for (int i = 65; i <= 90; i++) { // 'A' to 'Z'
        final letter = String.fromCharCode(i);
        final path = '$letter:\\';
        try {
          if (Directory(path).existsSync()) {
            drives.add({'name': 'Local Disk ($letter:)', 'path': path});
          }
        } catch (_) {}
      }
    } else if (Platform.isAndroid) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        drives.add({'name': 'Internal Storage (App Data)', 'path': docsDir.path});
      } catch (_) {}
      
      try {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (int i = 0; i < extDirs.length; i++) {
            final path = extDirs[i].path;
            if (i == 0) {
              drives.add({'name': 'Primary External Storage', 'path': path});
            } else {
              drives.add({'name': 'SD Card / External Storage $i', 'path': path});
            }
          }
        }
      } catch (_) {}
    } else {
      final home = Platform.environment['HOME'] ?? '/';
      drives.add({'name': 'Home Directory', 'path': home});
    }
    return drives;
  }

  Future<void> _selectPrimaryDrive(String path) async {
    setState(() {
      _isValidating = true;
      _validatingDrivePath = path;
    });

    // Premium micro-animation validation delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Validate drive availability
    final exists = Directory(path).existsSync();
    
    if (exists) {
      await SettingsService.instance.setPrimaryDrive(path);
      await SettingsService.instance.setBackupDirectory(null);
      await SettingsService.instance.setGoogleDriveConnection(enabled: false);
      
      final backupDir = await SettingsService.instance.getBackupDirectory();
      setState(() {
        _primaryDrive = path;
        _backupDirectory = backupDir;
        _gdriveEnabled = false;
        _gdriveCloudSyncConnected = false;
        _isValidating = false;
        _validatingDrivePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup location successfully updated.', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      setState(() {
        _isValidating = false;
        _validatingDrivePath = null;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Drive Unavailable',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Location $path is not currently accessible. Please verify permissions or connections and try again.',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }
    }
  }




  void _runGoogleOAuthFlow() async {
    try {
      // Connect to Google Sign-In
      final account = await GDriveService.instance.signIn();
      if (account != null) {
        await SettingsService.instance.setGoogleDriveConnection(
          enabled: true,
          email: account.email,
          name: account.displayName,
          photoUrl: account.photoUrl,
        );
        _loadBackupSettings();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connection Failed',
                    style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Text(
              'Google Drive connection failed: $e',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.poppins(color: AppColors.primary)),
              )
            ],
          ),
        );
      }
    }
  }

  Future<void> _disconnectGoogleAccount() async {
    await GDriveService.instance.signOut();
    await SettingsService.instance.setGoogleDriveConnection(enabled: false);
    setState(() {
      _gdriveEnabled = false;
      _gdriveCloudSyncConnected = false;
      _gdriveAccount = null;
      _gdriveName = null;
      _backupHistory = [];
    });
    _loadBackupSettings();
  }

  void _showBackupPassphraseDialog() {
    if (!_gdriveEnabled && _backupDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a Backup Location first.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    _passphraseCtrl.clear();
    _confirmCtrl.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Secure Backup Passphrase',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This passphrase will encrypt your passwords and documents backup.',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    PassphraseField(
                      label: 'Enter Passphrase',
                      hint: 'Create a backup passphrase',
                      controller: _passphraseCtrl,
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder(
                      valueListenable: _passphraseCtrl,
                      builder: (context, value, child) => PasswordStrengthIndicator(strength: _strength),
                    ),
                    const SizedBox(height: 16),
                    PassphraseField(
                      label: 'Confirm Passphrase',
                      hint: 'Re-enter passphrase',
                      controller: _confirmCtrl,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_passphraseCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a passphrase', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  if (_passphraseCtrl.text != _confirmCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Passphrases do not match', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _executeBackup(_passphraseCtrl.text);
                },
                child: Text(
                  'Backup',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<int> _calculateBackupSize() async {
    int totalSize = 0;
    try {
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'securevault.db'));
      if (await dbFile.exists()) {
        totalSize += await dbFile.length();
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, 'documents'));
      if (await docsDir.exists()) {
        await for (final file in docsDir.list(recursive: true)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
    } catch (_) {}
    return totalSize;
  }

  Future<void> _executeBackup(String passphrase) async {
    setState(() => _isBackingUp = true);

    try {
      // Validate available storage before starting backup
      final backupSize = await _calculateBackupSize();
      
      if (_gdriveEnabled && _gdrivePath == null) {
        // Direct cloud sync validation
        final quota = await GDriveService.instance.getStorageQuota();
        final remaining = quota['remaining'] ?? 0;
        if (backupSize > remaining) {
          throw Exception('Insufficient Google Drive space. Needed: ${_formatBytes(backupSize)}, Free: ${_formatBytes(remaining)}');
        }
      }

      // Fetch data from DB
      final dbHelper = DatabaseHelper.instance;
      final passwords = await dbHelper.readAllPasswords();
      final documents = await dbHelper.readAllDocuments();

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

      if (_gdriveEnabled && _gdrivePath == null) {
        // Direct Cloud Sync API Upload
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploading encrypted packages to Google Drive Cloud...', style: GoogleFonts.poppins()),
              backgroundColor: AppColors.primary,
            ),
          );
        }

        // Save temp files locally to upload them
        final tempDir = await getTemporaryDirectory();
        final pwTemp = File(p.join(tempDir.path, 'vault_backup.pwm'));
        await pwTemp.writeAsBytes(pwBytes);

        final docTemp = File(p.join(tempDir.path, 'documents_backup.sdm'));
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

        setState(() => _isBackingUp = false);
        _showSuccessDialog('Google Drive Cloud (Application Backups/$folderName)');
        _fetchGDriveMetadata();
      } else {
        // Local path write (standard disk or google sync folder)
        final backupLocation = _backupDirectory;
        if (backupLocation == null) throw Exception('No backup folder path is configured.');

        if (!Directory(backupLocation).existsSync()) {
          try {
            await Directory(backupLocation).create(recursive: true);
          } catch (_) {
            throw Exception('Failed to access backup folder $backupLocation.');
          }
        }

        final backupDir = Directory(p.join(backupLocation, folderName));
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }

        // Save files
        final pwFile = File(p.join(backupDir.path, 'vault_backup.pwm'));
        await pwFile.writeAsBytes(pwBytes);

        final docFile = File(p.join(backupDir.path, 'documents_backup.sdm'));
        await docFile.writeAsBytes(docBytes);

        setState(() => _isBackingUp = false);
        _showSuccessDialog(backupDir.path);
      }
    } catch (e) {
      setState(() => _isBackingUp = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Backup Failed', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            content: Text(
              e.toString(),
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.poppins(color: AppColors.primary)),
              )
            ],
          ),
        );
      }
    }
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 48,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Backup Created Successfully!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your encrypted backups have been stored successfully in:\n\n$path',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Done',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Backup & Recovery',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            // Current Primary Location details
                            _buildPrimaryLocationCard(),
                            const SizedBox(height: 28),
                            // Google Drive account status dashboard (if linked)
                            if (_gdriveCloudSyncConnected) ...[
                              _buildGDriveStatusDashboard(),
                              const SizedBox(height: 28),
                            ],
                            // Available Locations section
                            Text(
                              'AVAILABLE STORAGE DESTINATIONS',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 10),
                            _buildLocationsList(),
                            const SizedBox(height: 28),
                            // Cloud history if connected
                            if (_gdriveCloudSyncConnected) ...[
                              _buildCloudHistoryPanel(),
                              const SizedBox(height: 40),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildPrimaryLocationCard() {
    final driveConfigured = _gdriveEnabled;
    String locationText = 'Not Configured';

    if (_gdriveEnabled) {
      locationText = _gdrivePath ?? 'Google Drive (Cloud Sync: $_gdriveAccount)';
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (driveConfigured ? AppColors.primary : AppColors.warning).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _gdriveEnabled
                      ? Icons.cloud_done_rounded
                      : Icons.warning_amber_rounded,
                  color: _gdriveEnabled ? const Color(0xFF34A853) : AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primary Backup Destination',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      locationText,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (driveConfigured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Active',
                    style: GoogleFonts.poppins(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _gdriveEnabled
                ? (_gdrivePath != null
                    ? 'Sync folder configured. Backups will synchronize locally and upload to your Google Drive automatically.'
                    : 'Cloud account connected. Backups will sync to your secure Google Drive folder ("Application Backups").')
                : 'Connect and enable Google Drive Cloud sync to secure your vault data automatically.',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildGDriveStatusDashboard() {
    double progress = 0;
    if (_gdriveTotalSpace > 0) {
      progress = _gdriveUsedSpace / _gdriveTotalSpace;
    }
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_queue_rounded, color: Color(0xFF34A853), size: 22),
              const SizedBox(width: 10),
              Text(
                'Google Drive Account',
                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              OutlineButton(
                label: 'Disconnect',
                onTap: _disconnectGoogleAccount,
                width: 90,
                height: 30,
                fontSize: 10,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_gdriveName != null && _gdriveName!.isNotEmpty) ...[
            Text(
              _gdriveName!,
              style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            _gdriveAccount ?? '',
            style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34A853)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage Quota',
                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
              ),
              Text(
                '${_formatBytes(_gdriveUsedSpace)} / ${_formatBytes(_gdriveTotalSpace)} used',
                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          // Auto Backup toggle inside Connected settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatic Cloud Sync',
                    style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Auto-upload database updates to Google Drive',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              Switch(
                value: _autoBackupEnabled,
                onChanged: (v) {
                  setState(() => _autoBackupEnabled = v);
                  SettingsService.instance.saveSetting('auto_backup_enabled', v);
                },
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudHistoryPanel() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Cloud Backup History',
                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_loadingHistory)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
                  onPressed: _fetchGDriveMetadata,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_backupHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _loadingHistory ? 'Loading history...' : 'No cloud backups found in "Application Backups".',
                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _backupHistory.length > 5 ? 5 : _backupHistory.length, // Show last 5
              itemBuilder: (context, idx) {
                final file = _backupHistory[idx];
                final size = int.tryParse(file.size ?? '0') ?? 0;
                final created = file.createdTime ?? DateTime.now();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: Color(0xFF34A853), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name ?? '',
                              style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Uploaded: ${created.toLocal().toString().substring(0, 16)} · ${_formatBytes(size)}',
                              style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLocationsList() {
    return Column(
      children: [
        _buildGoogleDriveDestinationCard(),
      ],
    );
  }

  Widget _buildGoogleDriveDestinationCard() {
    final isSelected = _gdriveEnabled;
    return SolidCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isSelected ? const Color(0xFF34A853).withValues(alpha: 0.08) : AppColors.surface,
      onTap: _isValidating ? null : () {
        if (_gdriveCloudSyncConnected) {
          // If already connected, clicking sets it as primary
          setState(() {
            _gdriveEnabled = true;
            _primaryDrive = null;
          });
          SettingsService.instance.setGoogleDriveConnection(
            enabled: true,
            email: _gdriveAccount,
            name: _gdriveName,
            path: _gdrivePath,
            photoUrl: _gdrivePhoto,
          );
          SettingsService.instance.setPrimaryDrive('');
        } else {
          _runGoogleOAuthFlow();
        }
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF34A853).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.cloud_done_rounded,
                color: Color(0xFF34A853),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google Drive Cloud',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _gdriveCloudSyncConnected
                      ? 'Connected: ${_gdriveName ?? _gdriveAccount}'
                      : 'Tap to connect with Google OAuth 2.0 API',
                  style: GoogleFonts.poppins(
                    color: _gdriveCloudSyncConnected ? const Color(0xFF34A853) : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF34A853),
              size: 22,
            )
          else
            const Icon(
              Icons.radio_button_off_rounded,
              color: AppColors.textHint,
              size: 22,
            )
        ],
      ),
    ).animate().fadeIn(delay: 220.ms).slideX(begin: 0.05, end: 0);
  }



  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                Icons.key_rounded,
                'Passwords',
                false,
                () => Navigator.pushReplacementNamed(context, '/dashboard'),
              ),
              _navItem(
                Icons.folder_rounded,
                'Documents',
                false,
                () => Navigator.pushNamed(context, '/documents'),
              ),
              const SizedBox(width: 48), // Spacer for center docked button if any
              _navItem(Icons.backup_rounded, 'Backup', true, () {}),
              _navItem(
                Icons.settings_rounded,
                'Settings',
                false,
                () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


