import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_helper.dart';
import '../models/password_item.dart';
import '../services/gdrive_service.dart';
import '../services/encryption_helper.dart';

class ImportPasswordsScreen extends StatefulWidget {
  const ImportPasswordsScreen({super.key});

  @override
  State<ImportPasswordsScreen> createState() => _ImportPasswordsScreenState();
}

class _ImportPasswordsScreenState extends State<ImportPasswordsScreen> {
  final _passphraseCtrl = TextEditingController();
  PlatformFile? _selectedFile;
  bool _importing = false;
  bool _importFromGDrive = false;
  bool _gdriveConnected = false;
  List<drive.File> _gdriveFiles = [];
  drive.File? _selectedGDriveFile;
  bool _loadingGDriveFiles = false;

  @override
  void initState() {
    super.initState();
    _checkGDriveStatus();
  }

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    super.dispose();
  }

  void _checkGDriveStatus() async {
    final signedIn = await GDriveService.instance.isSignedIn();
    if (mounted) {
      setState(() {
        _gdriveConnected = signedIn;
      });
      if (signedIn) {
        _fetchGDriveFiles();
      }
    }
  }

  void _connectGDrive() async {
    try {
      final account = await GDriveService.instance.signIn();
      if (account != null) {
        setState(() {
          _gdriveConnected = true;
        });
        _fetchGDriveFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _fetchGDriveFiles() async {
    setState(() => _loadingGDriveFiles = true);
    try {
      final files = await GDriveService.instance.getBackupHistory();
      final pwmFiles = files.where((f) => f.name != null && f.name!.endsWith('.pwm')).toList();
      setState(() {
        _gdriveFiles = pwmFiles;
        _loadingGDriveFiles = false;
      });
    } catch (_) {
      setState(() => _loadingGDriveFiles = false);
    }
  }

  bool get _fileSelected => _selectedFile != null;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pwm', 'json', 'csv'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _import() async {
    if (_importFromGDrive) {
      if (_selectedGDriveFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a backup file from Google Drive', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
        );
        return;
      }
    } else {
      if (!_fileSelected) return;
    }

    if (_passphraseCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the passphrase', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final passphrase = _passphraseCtrl.text;
    setState(() => _importing = true);

    try {
      // 1. Read bytes from selected file/source
      Uint8List? fileBytes;
      if (_importFromGDrive) {
        final downloadedBytes = await GDriveService.instance.downloadFile(_selectedGDriveFile!.id!);
        fileBytes = Uint8List.fromList(downloadedBytes);
      } else {
        fileBytes = _selectedFile!.bytes;
        if (fileBytes == null && _selectedFile!.path != null) {
          final file = File(_selectedFile!.path!);
          if (await file.exists()) {
            fileBytes = await file.readAsBytes();
          }
        }
      }

      if (fileBytes == null) {
        throw Exception('Could not read file data. Try selecting it again.');
      }

      // 2. Parse backup structure
      final backupString = utf8.decode(fileBytes);
      final Map<String, dynamic> backupPayload = jsonDecode(backupString);

      final version = backupPayload['version'];
      if ((version != 1 && version != 2) ||
          backupPayload['iv'] == null ||
          backupPayload['ciphertext'] == null) {
        throw Exception('Invalid or unsupported backup file format.');
      }

      final ciphertext = backupPayload['ciphertext'];
      final ivBase64 = backupPayload['iv'];
      final saltBase64 = backupPayload['salt'] as String?;

      // 4. Decrypt payload off-thread on Isolate
      final decryptedString = await EncryptionHelper.decryptData(
        passphrase: passphrase,
        ciphertextBase64: ciphertext,
        ivBase64: ivBase64,
        saltBase64: saltBase64,
      );

      // 5. Parse decrypted list of passwords
      final List<dynamic> passwordMaps = jsonDecode(decryptedString);
      final importedPasswords = passwordMaps.map((map) => PasswordItem.fromMap(map)).toList();

      // 6. Merge/insert passwords into database using batch transaction
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.importPasswords(importedPasswords);
      final importedCount = importedPasswords.length;

      if (mounted) {
        setState(() => _importing = false);
        
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
                  'Import Successful!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Successfully imported $importedCount passwords from:\n${_selectedFile?.name}',
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
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
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
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ArgumentError || e is FormatException || e.toString().contains('MAC') || e.toString().contains('padding')
                  ? 'Incorrect passphrase or corrupted file.'
                  : 'Failed to import: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
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
                      'Import Passwords',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.4),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ).animate().scale(
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                        begin: const Offset(0.6, 0.6),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Import Passwords',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      Text(
                        'Import your passwords from file',
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 280.ms),
                      const SizedBox(height: 32),
                      // File picker
                      // Import source selector
                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IMPORT SOURCE',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            RadioListTile<bool>(
                              value: false,
                              groupValue: _importFromGDrive,
                              onChanged: (v) {
                                setState(() {
                                  _importFromGDrive = v!;
                                });
                              },
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Local File Storage',
                                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                'Select a local .pwm file from your device',
                                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ),
                            const Divider(color: AppColors.border, height: 1),
                            RadioListTile<bool>(
                              value: true,
                              groupValue: _importFromGDrive,
                              onChanged: (v) {
                                setState(() {
                                  _importFromGDrive = v!;
                                });
                                if (v! && !_gdriveConnected) {
                                  _checkGDriveStatus();
                                }
                              },
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Google Drive Cloud',
                                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                'Import from secure Google Drive folder',
                                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 320.ms),
                      const SizedBox(height: 24),
                      if (!_importFromGDrive) ...[
                        GestureDetector(
                          onTap: _pickFile,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _fileSelected
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _fileSelected
                                    ? AppColors.success
                                    : AppColors.border,
                                width: 1.5,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _fileSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.folder_open_rounded,
                                  color: _fileSelected
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  size: 36,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _fileSelected
                                      ? _selectedFile!.name
                                      : 'Choose File',
                                  style: GoogleFonts.poppins(
                                    color: _fileSelected
                                        ? AppColors.success
                                        : AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _fileSelected
                                      ? '${_formatFileSize(_selectedFile!.size)} · .${_selectedFile!.extension ?? "pwm"}'
                                      : 'Tap to select .pwm file',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 360.ms),
                      ] else ...[
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.cloud_done_rounded, color: Color(0xFF34A853), size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Google Drive Backups',
                                    style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  if (_gdriveConnected && !_loadingGDriveFiles)
                                    IconButton(
                                      icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
                                      onPressed: _fetchGDriveFiles,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (!_gdriveConnected)
                                GradientButton(
                                  label: 'Connect Google Drive',
                                  icon: Icons.cloud_queue_rounded,
                                  onTap: _connectGDrive,
                                )
                              else if (_loadingGDriveFiles)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                                  ),
                                )
                              else if (_gdriveFiles.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    'No password backups found in "Application Backups" folder.',
                                    style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                )
                              else
                                DropdownButtonFormField<drive.File>(
                                  value: _selectedGDriveFile,
                                  dropdownColor: AppColors.surface,
                                  isExpanded: true,
                                  style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Select Backup File',
                                    labelStyle: GoogleFonts.poppins(color: AppColors.textSecondary),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: _gdriveFiles.map((file) {
                                    final size = int.tryParse(file.size ?? '0') ?? 0;
                                    final sizeText = _formatFileSize(size);
                                    return DropdownMenuItem<drive.File>(
                                      value: file,
                                      child: Text(
                                        '${file.name} ($sizeText)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (file) {
                                    setState(() {
                                      _selectedGDriveFile = file;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 360.ms),
                      ],
                      const SizedBox(height: 24),
                      PassphraseField(
                        label: 'Enter Passphrase',
                        hint: 'Enter the export passphrase',
                        controller: _passphraseCtrl,
                      ).animate().fadeIn(delay: 440.ms),
                      const SizedBox(height: 12),
                      Text(
                        'Supported formats: .pwm, .json, .csv',
                        style: GoogleFonts.poppins(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ).animate().fadeIn(delay: 480.ms),
                      const SizedBox(height: 32),
                      _importing
                          ? Column(
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Decrypting & importing...',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : GradientButton(
                                  label: 'Import',
                                  icon: Icons.upload_rounded,
                                  onTap: _import,
                                )
                                .animate()
                                .fadeIn(delay: 560.ms)
                                .slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
