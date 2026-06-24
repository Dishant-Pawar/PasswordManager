import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_helper.dart';
import '../models/document_item.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  final _search = TextEditingController();
  List<DocumentItem> _documents = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadDocuments();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    final docs = await DatabaseHelper.instance.readAllDocuments();
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  Future<void> _deleteDocument(DocumentItem d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Document?',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${d.name}"?',
          style: GoogleFonts.poppins(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (d.filePath.isNotEmpty) {
          final file = File(d.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        if (d.id != null) {
          await DatabaseHelper.instance.deleteDocument(d.id!);
        }
        _loadDocuments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document deleted successfully', style: GoogleFonts.poppins()),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete document: $e', style: GoogleFonts.poppins()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _shareSelectedDocuments() async {
    final selectedDocs = _documents.where((d) => d.id != null && _selectedIds.contains(d.id)).toList();
    if (selectedDocs.isEmpty) return;

    List<XFile> filesToShare = [];
    for (final doc in selectedDocs) {
      if (doc.filePath.isNotEmpty) {
        final file = File(doc.filePath);
        if (await file.exists()) {
          filesToShare.add(XFile(doc.filePath, name: doc.name));
        }
      }
    }

    if (filesToShare.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No valid files found to share', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: filesToShare,
          subject: 'Shared Documents',
        ),
      );
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share documents: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedDocuments() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete $count Documents?',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete the selected $count documents?',
          style: GoogleFonts.poppins(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final selectedDocs = _documents.where((d) => d.id != null && _selectedIds.contains(d.id)).toList();
        for (final d in selectedDocs) {
          if (d.filePath.isNotEmpty) {
            final file = File(d.filePath);
            if (await file.exists()) {
              await file.delete();
            }
          }
          await DatabaseHelper.instance.deleteDocument(d.id!);
        }
        
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
        _loadDocuments();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count documents deleted successfully', style: GoogleFonts.poppins()),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete documents: $e', style: GoogleFonts.poppins()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadDocument(DocumentItem d) async {
    if (d.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid file path', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final file = File(d.filePath);
    final exists = await file.exists();
    if (!mounted) return;
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File does not exist or was deleted', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final params = SaveFileDialogParams(sourceFilePath: d.filePath);
      final savedPath = await FlutterFileDialog.saveFile(params: params);
      
      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document successfully saved/downloaded.', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save document: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _shareDocument(DocumentItem d) async {
    if (d.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid file path', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final file = File(d.filePath);
    final exists = await file.exists();
    if (!mounted) return;
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File does not exist or was deleted', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(d.filePath, name: d.name)],
          subject: d.name,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share document: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<DocumentItem> get _filteredDocuments {
    final query = _search.text.toLowerCase();
    if (query.isEmpty) return _documents;
    return _documents.where((d) => d.name.toLowerCase().contains(query)).toList();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isSelectionMode
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                                    onPressed: () {
                                      setState(() {
                                        _isSelectionMode = false;
                                        _selectedIds.clear();
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedIds.length} Selected',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                                    onPressed: _selectedIds.isEmpty ? null : _shareSelectedDocuments,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                    onPressed: _selectedIds.isEmpty ? null : _deleteSelectedDocuments,
                                  ),
                                ],
                              ),
                            ],
                          ).animate().fadeIn(duration: 300.ms)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Documents',
                                style: GoogleFonts.poppins(
                                  color: AppColors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _documents.length == 1
                                      ? '1 file'
                                      : '${_documents.length} files',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _search,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search documents...',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : _filteredDocuments.isEmpty
                        ? Center(
                            child: Text(
                              _search.text.isEmpty
                                  ? 'No documents uploaded yet'
                                  : 'No matching documents',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredDocuments.length,
                            itemBuilder: (context, i) {
                              final d = _filteredDocuments[i];
                              return GestureDetector(
                                 onLongPress: () {
                                   if (!_isSelectionMode) {
                                     setState(() {
                                       _isSelectionMode = true;
                                       if (d.id != null) {
                                         _selectedIds.add(d.id!);
                                       }
                                     });
                                   }
                                 },
                                 child: DocumentTile(
                                   name: d.name,
                                   size: _formatFileSize(d.sizeBytes),
                                   type: d.fileType,
                                   isSelected: d.id != null && _selectedIds.contains(d.id),
                                   isSelectionMode: _isSelectionMode,
                                   onTap: () async {
                                     if (_isSelectionMode) {
                                       setState(() {
                                         if (d.id != null) {
                                           if (_selectedIds.contains(d.id)) {
                                             _selectedIds.remove(d.id!);
                                             if (_selectedIds.isEmpty) {
                                               _isSelectionMode = false;
                                             }
                                           } else {
                                             _selectedIds.add(d.id!);
                                           }
                                         }
                                       });
                                     } else {
                                       if (d.filePath.isEmpty) {
                                         ScaffoldMessenger.of(context).showSnackBar(
                                           SnackBar(
                                             content: Text('Invalid file path', style: GoogleFonts.poppins()),
                                             backgroundColor: AppColors.error,
                                           ),
                                         );
                                         return;
                                       }
                                       final file = File(d.filePath);
                                       if (await file.exists()) {
                                         try {
                                           await OpenFilex.open(d.filePath);
                                         } catch (e) {
                                           if (context.mounted) {
                                             ScaffoldMessenger.of(context).showSnackBar(
                                               SnackBar(
                                                 content: Text('Could not open file: $e', style: GoogleFonts.poppins()),
                                                 backgroundColor: AppColors.error,
                                               ),
                                             );
                                           }
                                         }
                                       } else {
                                         if (context.mounted) {
                                           ScaffoldMessenger.of(context).showSnackBar(
                                             SnackBar(
                                               content: Text('File does not exist or was deleted', style: GoogleFonts.poppins()),
                                               backgroundColor: AppColors.error,
                                             ),
                                           );
                                         }
                                       }
                                     }
                                   },
                                   onDelete: () => _deleteDocument(d),
                                   onDownload: () => _downloadDocument(d),
                                   onShare: () => _shareDocument(d),
                                 ),
                               )
                                  .animate()
                                  .fadeIn(delay: Duration(milliseconds: 100 * i))
                                  .slideX(begin: 0.1, end: 0);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/upload-document');
          _loadDocuments();
        },
        backgroundColor: AppColors.accent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
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
              _navItem(Icons.folder_rounded, 'Documents', true, () {}),
              const SizedBox(width: 48),
              _navItem(
                Icons.backup_rounded,
                'Backup',
                false,
                () => Navigator.pushNamed(context, '/backup'),
              ),
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
