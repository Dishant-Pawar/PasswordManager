import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_helper.dart';
import '../models/document_item.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  final _nameCtrl = TextEditingController();
  String? _selectedCategory;
  PlatformFile? _selectedFile;
  bool _uploading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          if (_nameCtrl.text.isEmpty) {
            // Auto fill name if empty
            final baseName = _selectedFile!.name.split('.').first;
            _nameCtrl.text = baseName;
          }
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

  void _upload() async {
    if (!_fileSelected) return;
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a document name', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _uploading = true);
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savedDir = Directory(p.join(appDir.path, 'documents'));
      if (!await savedDir.exists()) {
        await savedDir.create(recursive: true);
      }
      
      final extension = _selectedFile?.extension ?? '';
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
      final savedPath = p.join(savedDir.path, uniqueName);
      
      if (_selectedFile!.path != null) {
        final sourceFile = File(_selectedFile!.path!);
        await sourceFile.copy(savedPath);
      } else if (_selectedFile!.bytes != null) {
        final destFile = File(savedPath);
        await destFile.writeAsBytes(_selectedFile!.bytes!);
      } else {
        throw Exception("Invalid file content");
      }

      final document = DocumentItem(
        name: _nameCtrl.text,
        filePath: savedPath,
        fileType: extension,
        sizeBytes: _selectedFile?.size ?? 0,
      );
      await DatabaseHelper.instance.createDocument(document);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save document: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _uploading = false);
      
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
                'Upload Successful!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Successfully uploaded and encrypted:\n${_nameCtrl.text}',
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

  final _categories = [
    'Identity',
    'Finance',
    'Medical',
    'Legal',
    'Education',
    'Other',
  ];

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
                    Expanded(
                      child: Text(
                        'Upload Document',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _upload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Upload',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // File picker
                      GestureDetector(
                        onTap: _pickFile,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: _fileSelected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _fileSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  _fileSelected
                                      ? Icons.insert_drive_file_rounded
                                      : Icons.cloud_upload_rounded,
                                  color: AppColors.primary,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _fileSelected ? _selectedFile!.name : 'Choose File',
                                style: GoogleFonts.poppins(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _fileSelected
                                    ? '${_formatFileSize(_selectedFile!.size)} · ${_selectedFile!.extension?.toUpperCase() ?? "Document"}'
                                    : 'Supported: pdf, jpg, png, docx',
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 24),
                      SVaultTextField(
                        label: 'Document Name',
                        hint: 'Enter document name',
                        controller: _nameCtrl,
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 20),
                      // Category dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category (Optional)',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            hint: Text(
                              'Select category',
                              style: GoogleFonts.poppins(
                                color: AppColors.textHint,
                                fontSize: 14,
                              ),
                            ),
                            dropdownColor: AppColors.surface,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary,
                            ),
                            decoration: const InputDecoration(),
                            items: _categories.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v),
                          ),
                        ],
                      ).animate().fadeIn(delay: 380.ms),
                      const SizedBox(height: 32),
                      if (_uploading)
                        Column(
                          children: [
                            const LinearProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                              backgroundColor: AppColors.border,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Encrypting & uploading...',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      else
                        GradientButton(
                              label: 'Upload Document',
                              icon: Icons.upload_rounded,
                              onTap: _upload,
                            )
                            .animate()
                            .fadeIn(delay: 460.ms)
                            .slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Supported formats: pdf, jpg, png, docx',
                          style: GoogleFonts.poppins(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms),
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
