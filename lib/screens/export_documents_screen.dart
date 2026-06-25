import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_helper.dart';
import '../services/gdrive_service.dart';
import '../services/encryption_helper.dart';

class ExportDocumentsScreen extends StatefulWidget {
  const ExportDocumentsScreen({super.key});

  @override
  State<ExportDocumentsScreen> createState() => _ExportDocumentsScreenState();
}

class _ExportDocumentsScreenState extends State<ExportDocumentsScreen> {
  final _passphraseCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _exporting = false;
  bool _exportToGDrive = false;
  bool _gdriveConnected = false;

  @override
  void initState() {
    super.initState();
    _checkGDriveStatus();
  }

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _checkGDriveStatus() async {
    final signedIn = await GDriveService.instance.isSignedIn();
    if (mounted) {
      setState(() {
        _gdriveConnected = signedIn;
      });
    }
  }

  void _connectGDrive() async {
    try {
      final account = await GDriveService.instance.signIn();
      if (account != null) {
        setState(() {
          _gdriveConnected = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to Google Drive as ${account.email}', style: GoogleFonts.poppins()),
              backgroundColor: AppColors.success,
            ),
          );
        }
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

  double get _strength {
    final v = _passphraseCtrl.text;
    double s = 0;
    if (v.length >= 8) s += 0.25;
    if (v.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (v.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (v.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.25;
    return s;
  }

  void _export() async {
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

    final passphrase = _passphraseCtrl.text;
    setState(() => _exporting = true);

    try {
      // 1. Get documents from database
      final dbHelper = DatabaseHelper.instance;
      final documents = await dbHelper.readAllDocuments();

      // 2. Convert to JSON map list, embedding the base64 encoded file content
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
      
      final jsonString = jsonEncode(docMaps);

      // 3. Encrypt data off-thread on Isolate
      final encryptedResult = await EncryptionHelper.encryptData(
        passphrase: passphrase,
        plaintext: jsonString,
      );

      // 4. Create the structured JSON backup payload (version 2)
      final backupPayload = {
        'version': 2,
        'salt': encryptedResult['salt']!,
        'iv': encryptedResult['iv']!,
        'ciphertext': encryptedResult['ciphertext']!,
      };
      
      final backupString = jsonEncode(backupPayload);
      final bytes = Uint8List.fromList(utf8.encode(backupString));

      if (_exportToGDrive) {
        if (!_gdriveConnected) {
          throw Exception('Google Drive is not connected. Please connect first.');
        }
        final now = DateTime.now();
        final timestamp = '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
        final driveFileName = 'documents_export_$timestamp.sdm';
        
        await GDriveService.instance.uploadFileBytes(
          bytes: bytes,
          driveFileName: driveFileName,
        );

        if (mounted) {
          setState(() => _exporting = false);
          _showSuccess('Google Drive: Application Backups/$driveFileName');
        }
        return;
      }

      // 7. Save file via FilePicker
      String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Export As:',
        fileName: 'documents_backup.sdm',
        type: FileType.custom,
        allowedExtensions: ['sdm'],
        bytes: bytes,
      );

      if (outputFile == null) {
        if (mounted) {
          setState(() => _exporting = false);
        }
        return;
      }

      // Write bytes to file on supported platforms
      try {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
      } catch (fileError) {
        // Fallback for environments where direct disk write is constrained
      }

      if (mounted) {
        setState(() => _exporting = false);
        _showSuccess(outputFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  void _showSuccess(String savedPath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 48,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export Successful!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Backup saved to:\n$savedPath',
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
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Export Documents',
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
                            colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.folder_zip_rounded,
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
                        'Export Documents',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      Text(
                        'Export all your documents securely',
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 280.ms),
                      const SizedBox(height: 32),
                      // Separate system notice
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Separate from Password Export',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Output: documents_backup.sdm',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 360.ms),
                      const SizedBox(height: 24),
                      // Destination selection
                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXPORT DESTINATION',
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
                              groupValue: _exportToGDrive,
                              onChanged: (v) {
                                setState(() {
                                  _exportToGDrive = v!;
                                });
                              },
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Local File Storage',
                                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                'Save as a local .sdm file on your device',
                                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ),
                            Divider(color: AppColors.border, height: 1),
                            RadioListTile<bool>(
                              value: true,
                              groupValue: _exportToGDrive,
                              onChanged: (v) {
                                setState(() {
                                  _exportToGDrive = v!;
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
                                'Export directly to secure Google Drive folder',
                                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ),
                            if (_exportToGDrive && !_gdriveConnected) ...[
                              const SizedBox(height: 12),
                              GradientButton(
                                label: 'Connect Google Drive',
                                icon: Icons.cloud_queue_rounded,
                                onTap: _connectGDrive,
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 24),
                      PassphraseField(
                        label: 'Enter Passphrase',
                        hint: 'Create an export passphrase',
                        controller: _passphraseCtrl,
                      ).animate().fadeIn(delay: 440.ms),
                      const SizedBox(height: 12),
                      ValueListenableBuilder(
                        valueListenable: _passphraseCtrl,
                        builder: (_, v, _) =>
                            PasswordStrengthIndicator(strength: _strength),
                      ).animate().fadeIn(delay: 460.ms),
                      const SizedBox(height: 20),
                      PassphraseField(
                        label: 'Confirm Passphrase',
                        hint: 'Re-enter passphrase',
                        controller: _confirmCtrl,
                      ).animate().fadeIn(delay: 520.ms),
                      const SizedBox(height: 32),
                      _exporting
                          ? Column(
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Encrypting documents...',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : GradientButton(
                                  label: 'Export',
                                  icon: Icons.download_rounded,
                                  onTap: _export,
                                )
                                .animate()
                                .fadeIn(delay: 600.ms)
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
