import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/password_item.dart';
import '../services/database_helper.dart';

class ViewPasswordScreen extends StatefulWidget {
  const ViewPasswordScreen({super.key});

  @override
  State<ViewPasswordScreen> createState() => _ViewPasswordScreenState();
}

class _ViewPasswordScreenState extends State<ViewPasswordScreen> {
  bool _showPassword = false;

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied!', style: GoogleFonts.poppins()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passwordItem = ModalRoute.of(context)?.settings.arguments as PasswordItem?;
    if (passwordItem == null) {
      return const Scaffold(body: Center(child: Text('Error: No password data')));
    }

    final createdStr = '${passwordItem.createdAt.year}-${passwordItem.createdAt.month.toString().padLeft(2, '0')}-${passwordItem.createdAt.day.toString().padLeft(2, '0')}';
    final updatedStr = '${passwordItem.updatedAt.year}-${passwordItem.updatedAt.month.toString().padLeft(2, '0')}-${passwordItem.updatedAt.day.toString().padLeft(2, '0')}';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/add-password',
                          arguments: passwordItem,
                        );
                      },
                      icon: Icon(Icons.edit_outlined, color: AppColors.primary),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (passwordItem.id != null) {
                          await DatabaseHelper.instance.deletePassword(passwordItem.id!);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Brand icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            passwordItem.title.isNotEmpty ? passwordItem.title[0].toUpperCase() : '?',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF4285F4),
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ).animate().scale(duration: 500.ms, curve: Curves.elasticOut, begin: const Offset(0.6, 0.6)),
                      const SizedBox(height: 12),
                      Text(
                        passwordItem.title.isNotEmpty ? passwordItem.title : 'Unnamed',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      if (passwordItem.url.isNotEmpty)
                        Text(
                          passwordItem.url,
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ).animate().fadeIn(delay: 250.ms),
                      const SizedBox(height: 28),
                      // Username
                      _InfoCard(
                        label: 'Username',
                        value: passwordItem.username,
                        onCopy: () => _copy('Username', passwordItem.username),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 12),
                      // Password
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _showPassword ? passwordItem.password : '●' * (passwordItem.password.length > 12 ? 12 : passwordItem.password.length),
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: _showPassword ? 0 : 2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                  icon: Icon(
                                    _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _copy('Password', passwordItem.password),
                                  icon: Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 380.ms).slideY(begin: 0.1, end: 0),
                      if (passwordItem.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        // Notes
                        _InfoCard(
                          label: 'Notes',
                          value: passwordItem.notes,
                        ).animate().fadeIn(delay: 520.ms).slideY(begin: 0.1, end: 0),
                      ],
                      const SizedBox(height: 12),
                      // Metadata
                      SolidCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _MetaRow(label: 'Created', value: createdStr),
                            Divider(color: AppColors.border, height: 20),
                            _MetaRow(label: 'Last Updated', value: updatedStr),
                          ],
                        ),
                      ).animate().fadeIn(delay: 580.ms),
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

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoCard({required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
        Text(
          value,
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
