import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ImportDocumentsScreen extends StatefulWidget {
  const ImportDocumentsScreen({super.key});

  @override
  State<ImportDocumentsScreen> createState() => _ImportDocumentsScreenState();
}

class _ImportDocumentsScreenState extends State<ImportDocumentsScreen> {
  final _passphraseCtrl = TextEditingController();
  PlatformFile? _selectedFile;
  bool _importing = false;

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
        allowedExtensions: ['sdm'],
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
    if (!_fileSelected) return;
    if (_passphraseCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the passphrase', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _importing = true);
    await Future.delayed(const Duration(seconds: 2));
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
                'Successfully imported documents from:\n${_selectedFile?.name}',
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
                      'Import Documents',
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
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF3B82F6).withValues(alpha: 0.4),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.folder_open_rounded,
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
                        'Import Documents',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      Text(
                        'Import your documents from file',
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 280.ms),
                      const SizedBox(height: 32),
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
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _fileSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.folder_zip_rounded,
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
                                    ? '${_formatFileSize(_selectedFile!.size)} · .${_selectedFile!.extension ?? "sdm"}'
                                    : 'Tap to select .sdm file',
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 360.ms),
                      const SizedBox(height: 24),
                      PassphraseField(
                        label: 'Enter Passphrase',
                        hint: 'Enter the export passphrase',
                        controller: _passphraseCtrl,
                      ).animate().fadeIn(delay: 440.ms),
                      const SizedBox(height: 12),
                      Text(
                        'Supported format: .sdm',
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
                                  icon: Icons.upload_file_rounded,
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
