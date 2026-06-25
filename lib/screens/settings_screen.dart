import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/settings_service.dart';
import '../services/database_helper.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  void reload() {
    _loadSettings();
  }
  bool _darkMode = true;
  bool _biometric = true;
  bool _autoBackup = false;
  String _autoBackupPassphrase = '';
  String _profileName = 'John Doe';
  String _profileEmail = 'john@example.com';
  String? _profilePhotoUrl;
  String? _profilePhotoPath;
  String _passwordHint = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.instance.loadSettings();
    setState(() {
      _darkMode = settings['dark_mode'] as bool? ?? true;
      _biometric = settings['biometric_enabled'] as bool? ?? true;
      _autoBackup = settings['auto_backup_enabled'] as bool? ?? false;
      _autoBackupPassphrase = settings['auto_backup_passphrase'] as String? ?? '';
      _profileName = settings['profile_name'] as String? ?? 'John Doe';
      _profileEmail = settings['profile_email'] as String? ?? 'john@example.com';
      _profilePhotoUrl = settings['profile_photo_url'] as String? ?? settings['gdrive_photo'] as String?;
      _profilePhotoPath = settings['profile_photo_path'] as String?;
      _passwordHint = settings['password_hint'] as String? ?? '';
    });
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Settings',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile card
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        onTap: _showEditProfileDialog,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage: _profilePhotoPath != null && File(_profilePhotoPath!).existsSync()
                                  ? FileImage(File(_profilePhotoPath!))
                                  : (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                                      ? NetworkImage(_profilePhotoUrl!)
                                      : null),
                              child: (_profilePhotoPath != null && File(_profilePhotoPath!).existsSync()) ||
                                      (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                                  ? null
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profileName,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _profileEmail,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 24),
                      // Security section
                      _SectionTitle(
                        title: 'Security',
                      ).animate().fadeIn(delay: 300.ms),
                      SolidCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            SettingsTile(
                              title: 'Auto Backup',
                              icon: Icons.backup_rounded,
                              iconColor: AppColors.success,
                              trailing: Switch(
                                value: _autoBackup,
                                onChanged: (v) async {
                                  setState(() => _autoBackup = v);
                                  await SettingsService.instance.saveSetting('auto_backup_enabled', v);
                                },
                                activeThumbColor: AppColors.primary,
                              ),
                            ),
                            if (_autoBackup) ...[
                              const Divider(
                                color: AppColors.border,
                                height: 1,
                                indent: 68,
                              ),
                              SettingsTile(
                                title: 'Auto Backup Passphrase',
                                subtitle: _autoBackupPassphrase.isEmpty
                                    ? 'Using default secure key'
                                    : 'Custom passphrase configured',
                                icon: Icons.key_rounded,
                                iconColor: AppColors.primary,
                                onTap: _showPassphraseDialog,
                              ),
                            ],
                            const Divider(
                              color: AppColors.border,
                              height: 1,
                              indent: 68,
                            ),
                            SettingsTile(
                              title: 'Fingerprint Lock',
                              icon: Icons.fingerprint_rounded,
                              iconColor: AppColors.primary,
                              trailing: Switch(
                                value: _biometric,
                                onChanged: (v) async {
                                  setState(() => _biometric = v);
                                  await SettingsService.instance.saveSetting('biometric_enabled', v);
                                },
                                activeThumbColor: AppColors.primary,
                              ),
                            ),
                            const Divider(
                              color: AppColors.border,
                              height: 1,
                              indent: 68,
                            ),
                            SettingsTile(
                              title: 'Change Master Password',
                              icon: Icons.lock_reset_rounded,
                              iconColor: AppColors.warning,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/change-master-password',
                              ),
                            ),
                            const Divider(
                              color: AppColors.border,
                              height: 1,
                              indent: 68,
                            ),
                            SettingsTile(
                              title: 'Update Password Hint',
                              icon: Icons.help_outline_rounded,
                              iconColor: AppColors.primary,
                              onTap: _showUpdateHintDialog,
                            ),
                            const Divider(
                              color: AppColors.border,
                              height: 1,
                              indent: 68,
                            ),
                            SettingsTile(
                              title: 'Dark Mode',
                              icon: Icons.dark_mode_rounded,
                              iconColor: AppColors.accent,
                              trailing: Switch(
                                value: _darkMode,
                                onChanged: (v) async {
                                  setState(() => _darkMode = v);
                                  await SettingsService.instance.saveSetting('dark_mode', v);
                                },
                                activeThumbColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 360.ms),
                      const SizedBox(height: 20),
                      // Data section
                      _SectionTitle(
                        title: 'Data',
                      ).animate().fadeIn(delay: 400.ms),
                      SolidCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            SettingsTile(
                              title: 'Export Passwords',
                              icon: Icons.upload_rounded,
                              iconColor: AppColors.primary,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/export-passwords',
                              ),
                            ),
                            const Divider(
                              color: AppColors.border,
                              height: 1,
                              indent: 68,
                            ),
                            SettingsTile(
                              title: 'Import Passwords',
                              icon: Icons.download_rounded,
                              iconColor: AppColors.success,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/import-passwords',
                              ),
                            ),
                            const Divider(
                              color: AppColors.border,
                              height: 1,
                              indent: 68,
                            ),
                            SettingsTile(
                              title: 'Export Documents',
                              icon: Icons.folder_zip_rounded,
                              iconColor: AppColors.accent,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/export-documents',
                              ),
                            ),
                            const Divider(
                              color: AppColors.border,
                              height: 1,
                              indent: 68,
                            ),
                            SettingsTile(
                              title: 'Import Documents',
                              icon: Icons.folder_open_rounded,
                              iconColor: Color(0xFF3B82F6),
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/import-documents',
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 460.ms),
                      const SizedBox(height: 20),
                      // About section
                      _SectionTitle(
                        title: 'About',
                      ).animate().fadeIn(delay: 500.ms),
                      SolidCard(
                        padding: EdgeInsets.zero,
                        child: SettingsTile(
                          title: 'About App',
                          subtitle: 'SecureVault v1.0.0',
                          icon: Icons.info_outline_rounded,
                          iconColor: AppColors.textSecondary,
                          onTap: () {},
                        ),
                      ).animate().fadeIn(delay: 540.ms),
                      const SizedBox(height: 20),
                      // Account section
                      _SectionTitle(
                        title: 'Account',
                      ).animate().fadeIn(delay: 580.ms),
                      SolidCard(
                        padding: EdgeInsets.zero,
                        child: SettingsTile(
                          title: 'Logout',
                          subtitle: 'Securely lock and exit your vault',
                          icon: Icons.logout_rounded,
                          iconColor: AppColors.error,
                          onTap: _showLogoutConfirmDialog,
                        ),
                      ).animate().fadeIn(delay: 620.ms),
                      const SizedBox(height: 100),
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

  void _showPassphraseDialog() {
    final controller = TextEditingController(text: _autoBackupPassphrase);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Auto Backup Passphrase',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify a custom passphrase to encrypt automatic cloud backups. If left empty, the system default secure key is used.',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SVaultTextField(
              label: 'Passphrase',
              hint: 'Enter passphrase',
              isPassword: true,
              controller: controller,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newPassphrase = controller.text;
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              setState(() {
                _autoBackupPassphrase = newPassphrase;
              });
              await SettingsService.instance.saveSetting('auto_backup_passphrase', newPassphrase);
              controller.dispose();
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Auto backup passphrase updated.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Text(
              'Save',
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

  void _showUpdateHintDialog() {
    final controller = TextEditingController(text: _passwordHint);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Update Password Hint',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify a password hint to help you remember your master password if you forget it. This is stored locally.',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SVaultTextField(
              label: 'Password Hint',
              hint: 'Enter your password hint',
              controller: controller,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newHint = controller.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              setState(() {
                _passwordHint = newHint;
              });
              await SettingsService.instance.saveSetting('password_hint', newHint.isEmpty ? null : newHint);
              controller.dispose();
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Password hint updated.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Text(
              'Save',
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

  Future<String?> _copyPickedFile(String originalPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory(p.join(appDir.path, 'profile_photos'));
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }
      final extension = p.extension(originalPath);
      final newFileName = 'profile_pic_${DateTime.now().millisecondsSinceEpoch}$extension';
      final newPath = p.join(profileDir.path, newFileName);
      
      final originalFile = File(originalPath);
      await originalFile.copy(newPath);
      return newPath;
    } catch (e) {
      debugPrint("Error copying profile photo: $e");
      return null;
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _profileName);
    final emailController = TextEditingController(text: _profileEmail);
    final photoUrlController = TextEditingController(text: _profilePhotoUrl ?? '');
    final formKey = GlobalKey<FormState>();

    String? localPhotoPath = _profilePhotoPath;
    String? localPhotoUrl = _profilePhotoUrl;

    StateSetter? updateDialog;

    photoUrlController.addListener(() {
      if (updateDialog != null) {
        final val = photoUrlController.text.trim();
        if (val != localPhotoUrl) {
          updateDialog!(() {
            localPhotoUrl = val;
            if (val.isNotEmpty) {
              localPhotoPath = null;
            }
          });
        }
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          updateDialog = setDialogState;
          final hasLocalFile = localPhotoPath != null && File(localPhotoPath!).existsSync();
          final hasUrl = localPhotoUrl != null && localPhotoUrl!.isNotEmpty;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Edit Profile',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: hasLocalFile
                          ? FileImage(File(localPhotoPath!))
                          : (hasUrl ? NetworkImage(localPhotoUrl!) : null),
                      child: hasLocalFile || hasUrl
                          ? null
                          : const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                              size: 40,
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.pickFiles(
                              type: FileType.image,
                              allowMultiple: false,
                            );
                            if (result != null && result.files.single.path != null && context.mounted) {
                              _showAdjustImageDialog(
                                context,
                                result.files.single.path!,
                                (adjustedPath) {
                                  setDialogState(() {
                                    localPhotoPath = adjustedPath;
                                    localPhotoUrl = '';
                                    photoUrlController.clear();
                                  });
                                },
                              );
                            }
                          },
                          icon: const Icon(Icons.photo_library_rounded, size: 16),
                          label: Text(
                            'Upload',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                        if (hasLocalFile || hasUrl) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                localPhotoPath = null;
                                localPhotoUrl = null;
                                photoUrlController.clear();
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: Text(
                              'Remove',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    SVaultTextField(
                      label: 'Name',
                      hint: 'Enter your name',
                      controller: nameController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SVaultTextField(
                      label: 'Email Address',
                      hint: 'Enter your email',
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return null;
                        }
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(val.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SVaultTextField(
                      label: 'Profile Picture URL',
                      hint: 'Enter image URL (optional)',
                      controller: photoUrlController,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  nameController.dispose();
                  emailController.dispose();
                  photoUrlController.dispose();
                  Navigator.pop(ctx);
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    final newName = nameController.text.trim();
                    final newEmail = emailController.text.trim();
                    final newPhotoUrl = photoUrlController.text.trim();
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(ctx);

                    String? finalPhotoPath = localPhotoPath;
                    if (localPhotoPath != null && localPhotoPath != _profilePhotoPath) {
                      finalPhotoPath = await _copyPickedFile(localPhotoPath!);
                    }

                    setState(() {
                      _profileName = newName;
                      _profileEmail = newEmail;
                      _profilePhotoUrl = newPhotoUrl.isNotEmpty ? newPhotoUrl : null;
                      _profilePhotoPath = finalPhotoPath;
                    });

                    await SettingsService.instance.saveSetting('profile_name', newName);
                    await SettingsService.instance.saveSetting('profile_email', newEmail);
                    await SettingsService.instance.saveSetting('profile_photo_url', newPhotoUrl);
                    await SettingsService.instance.saveSetting('profile_photo_path', finalPhotoPath);

                    nameController.dispose();
                    emailController.dispose();
                    photoUrlController.dispose();
                    navigator.pop();

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Profile updated successfully.',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAdjustImageDialog(
    BuildContext context,
    String imagePath,
    Function(String) onDone,
  ) {
    final boundaryKey = GlobalKey();
    final transformationController = TransformationController();
    int quarterTurns = 0;
    double currentZoom = 1.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Adjust Photo',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Drag to pan, pinch or use the slider to zoom. Rotate if needed.',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Stack(
                    children: [
                      ClipRect(
                        child: RepaintBoundary(
                          key: boundaryKey,
                          child: Container(
                            width: 250,
                            height: 250,
                            color: Colors.black,
                            child: Center(
                              child: InteractiveViewer(
                                transformationController: transformationController,
                                minScale: 0.1,
                                maxScale: 8.0,
                                onInteractionUpdate: (details) {
                                  final matrix = transformationController.value;
                                  final scale = matrix.getMaxScaleOnAxis();
                                  setDialogState(() {
                                    currentZoom = scale.clamp(1.0, 8.0);
                                  });
                                },
                                child: RotatedBox(
                                  quarterTurns: quarterTurns,
                                  child: Image.file(
                                    File(imagePath),
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: SizedBox(
                          width: 250,
                          height: 250,
                          child: CustomPaint(
                            painter: CropMaskPainter(
                              borderColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.zoom_out_rounded, color: AppColors.textSecondary, size: 20),
                    Expanded(
                      child: Slider(
                        value: currentZoom,
                        min: 1.0,
                        max: 8.0,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.border,
                        onChanged: (val) {
                          setDialogState(() {
                            currentZoom = val;
                          });
                          final matrix = Matrix4.diagonal3Values(val, val, 1.0);
                          transformationController.value = matrix;
                        },
                      ),
                    ),
                    const Icon(Icons.zoom_in_rounded, color: AppColors.textSecondary, size: 20),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      quarterTurns = (quarterTurns + 1) % 4;
                    });
                  },
                  icon: const Icon(Icons.rotate_right_rounded, color: AppColors.primary),
                  label: Text(
                    'Rotate 90°',
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final RenderRepaintBoundary? boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                    if (boundary == null) return;
                    
                    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                    if (byteData == null) return;
                    
                    final Uint8List pngBytes = byteData.buffer.asUint8List();
                    
                    final tempDir = await getTemporaryDirectory();
                    final tempPath = p.join(tempDir.path, 'adjusted_profile_${DateTime.now().millisecondsSinceEpoch}.png');
                    final file = File(tempPath);
                    await file.writeAsBytes(pngBytes);
                    
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      onDone(tempPath);
                    }
                  } catch (e) {
                    debugPrint("Error cropping image: $e");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to adjust photo. Please try again.', style: GoogleFonts.poppins()),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Apply',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to log out? This will lock your vault, and you will need your master password to unlock it again.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.pop(ctx);
              await DatabaseHelper.instance.logout();
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class CropMaskPainter extends CustomPainter {
  final Color borderColor;
  
  CropMaskPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()..addOval(Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    ));

    final path = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawOval(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

