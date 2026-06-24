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

import '../services/database_helper.dart';
import '../models/password_item.dart';
import '../services/settings_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _passwordCount = 0;
  int _documentCount = 0;
  List<PasswordItem> _recentPasswords = [];
  bool _isLoading = true;
  String _profileName = 'John Doe';
  String _profileEmail = 'john@example.com';
  String? _profilePhotoUrl;
  String? _profilePhotoPath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbHelper = DatabaseHelper.instance;
    final passwords = await dbHelper.readAllPasswords();
    final documents = await dbHelper.readAllDocuments();
    final settings = await SettingsService.instance.loadSettings();

    setState(() {
      _passwordCount = passwords.length;
      _documentCount = documents.length;
      _recentPasswords = passwords.take(3).toList();
      _profileName = settings['profile_name'] as String? ?? 'John Doe';
      _profileEmail = settings['profile_email'] as String? ?? 'john@example.com';
      _profilePhotoUrl = settings['profile_photo_url'] as String? ?? settings['gdrive_photo'] as String?;
      _profilePhotoPath = settings['profile_photo_path'] as String?;
      _isLoading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Good Morning,',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$_profileName 👋',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                               GestureDetector(
                                 onTap: _showEditProfileDialog,
                                 child: CircleAvatar(
                                   radius: 22,
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
                                           size: 22,
                                         ),
                                 ),
                               ),
                            ],
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 20),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search passwords, documents...',
                            hintStyle: GoogleFonts.poppins(
                              color: AppColors.textHint,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                            suffixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 150.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 24),
                      // Stats grid
                      GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.4,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.pushNamed(context, '/passwords');
                                  _loadData();
                                },
                                child: StatCard(
                                  value: _passwordCount.toString(),
                                  label: 'Passwords',
                                  icon: Icons.key_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.pushNamed(context, '/documents');
                                  _loadData();
                                },
                                child: StatCard(
                                  value: _documentCount.toString(),
                                  label: 'Documents',
                                  icon: Icons.folder_rounded,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 24),
                      // Recent activity
                      SectionHeader(
                        title: 'Recent Activity',
                        action: 'View all',
                        onAction: () async {
                          await Navigator.pushNamed(context, '/passwords');
                          _loadData();
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_recentPasswords.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No recent activity',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._recentPasswords.asMap().entries.map(
                          (e) {
                            final password = e.value;
                            return PasswordListTile(
                                  title: password.title.isNotEmpty ? password.title : 'Unnamed',
                                  username: password.username.isNotEmpty ? password.username : 'No username',
                                  initial: password.title.isNotEmpty ? password.title[0].toUpperCase() : '?',
                                  color: AppColors.primary, // Using primary color for all for now
                                  onTap: () async {
                                    await Navigator.pushNamed(
                                      context,
                                      '/view-password',
                                      arguments: password,
                                    );
                                    _loadData();
                                  },
                                )
                                .animate()
                                .fadeIn(
                                  delay: Duration(
                                    milliseconds: 600 + e.key * 100,
                                  ),
                                )
                                .slideX(begin: 0.1, end: 0);
                          }
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: 0,
        context: context,
        onSettingsReturn: _loadData,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add-password');
          _loadData();
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final BuildContext context;
  final VoidCallback? onSettingsReturn;

  const _BottomNav({
    required this.currentIndex,
    required this.context,
    this.onSettingsReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
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
                0,
                currentIndex,
                () => Navigator.pushReplacementNamed(context, '/dashboard'),
              ),
              _navItem(
                Icons.folder_rounded,
                'Documents',
                1,
                currentIndex,
                () => Navigator.pushNamed(context, '/documents'),
              ),
              const SizedBox(width: 48),
              _navItem(
                Icons.backup_rounded,
                'Backup',
                2,
                currentIndex,
                () => Navigator.pushNamed(context, '/backup'),
              ),
              _navItem(
                Icons.settings_rounded,
                'Settings',
                3,
                currentIndex,
                () async {
                  await Navigator.pushNamed(context, '/settings');
                  if (onSettingsReturn != null) {
                    onSettingsReturn!();
                  }
                },
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
    int index,
    int current,
    VoidCallback onTap,
  ) {
    final isActive = index == current;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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

