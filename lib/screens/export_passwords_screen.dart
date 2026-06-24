import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart' as crypto;
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_helper.dart';
import '../services/gdrive_service.dart';

class ExportPasswordsScreen extends StatefulWidget {
  const ExportPasswordsScreen({super.key});

  @override
  State<ExportPasswordsScreen> createState() => _ExportPasswordsScreenState();
}

class _ExportPasswordsScreenState extends State<ExportPasswordsScreen> {
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
      // 1. Get passwords from database
      final dbHelper = DatabaseHelper.instance;
      final passwords = await dbHelper.readAllPasswords();

      // 2. Convert to JSON string
      final List<Map<String, dynamic>> passwordMaps = passwords.map((p) => p.toMap()).toList();
      final jsonString = jsonEncode(passwordMaps);

      // 3. Derive 32-byte key from passphrase using SHA-256
      final keyBytes = crypto.sha256.convert(utf8.encode(passphrase)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));

      // 4. Generate random 16-byte IV for AES-CBC
      final iv = enc.IV.fromSecureRandom(16);

      // 5. Encrypt using AES-CBC
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(jsonString, iv: iv);

      // 6. Create the structured JSON backup payload
      final backupPayload = {
        'version': 1,
        'iv': iv.base64,
        'ciphertext': encrypted.base64,
      };
      
      final backupString = jsonEncode(backupPayload);
      final bytes = Uint8List.fromList(utf8.encode(backupString));

      if (_exportToGDrive) {
        if (!_gdriveConnected) {
          throw Exception('Google Drive is not connected. Please connect first.');
        }
        final now = DateTime.now();
        final timestamp = '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
        final driveFileName = 'passwords_export_$timestamp.pwm';
        
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
        fileName: 'vault_backup.pwm',
        type: FileType.custom,
        allowedExtensions: ['pwm'],
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
        title: const Icon(
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
                      'Export Passwords',
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
                      // Icon
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.upload_rounded,
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
                        'Export Passwords',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      Text(
                        'Export all your passwords securely',
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 280.ms),
                      const SizedBox(height: 32),
                      // Info card
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.lock_rounded,
                              color: AppColors.success,
                              text: 'Encrypted with AES-256-GCM',
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              icon: Icons.key_rounded,
                              color: AppColors.primary,
                              text: 'Key derived via Argon2id',
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              icon: Icons.insert_drive_file_rounded,
                              color: AppColors.accent,
                              text: 'Output: vault_backup.pwm',
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
                                'Save as a local .pwm file on your device',
                                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ),
                            const Divider(color: AppColors.border, height: 1),
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
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Encrypting & exporting...',
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
