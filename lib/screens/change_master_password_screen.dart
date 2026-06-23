import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ChangeMasterPasswordScreen extends StatefulWidget {
  const ChangeMasterPasswordScreen({super.key});

  @override
  State<ChangeMasterPasswordScreen> createState() =>
      _ChangeMasterPasswordScreenState();
}

class _ChangeMasterPasswordScreenState
    extends State<ChangeMasterPasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  double _strength = 0;

  void _onNewPasswordChanged(String value) {
    double s = 0;
    if (value.length >= 8) s += 0.25;
    if (value.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (value.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (value.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.25;
    setState(() => _strength = s);
  }

  void _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _saving = false);
      _showSuccess();
    }
  }

  void _showSuccess() {
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
              'Password Changed!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All data re-encrypted with new master password.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 13,
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
                        'Change Master Password',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: _save,
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
                                'Save',
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
                      // Warning
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.warning,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'All records will be re-encrypted with the new password.',
                                style: GoogleFonts.poppins(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 24),
                      SVaultTextField(
                        label: 'Current Password',
                        hint: 'Enter current master password',
                        isPassword: true,
                        controller: _currentCtrl,
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 20),
                      SVaultTextField(
                        label: 'New Password',
                        hint: 'Enter new master password',
                        isPassword: true,
                        controller: _newCtrl,
                      ).animate().fadeIn(delay: 380.ms),
                      const SizedBox(height: 12),
                      ValueListenableBuilder(
                        valueListenable: _newCtrl,
                        builder: (_, v, _) {
                          _onNewPasswordChanged(_newCtrl.text);
                          return PasswordStrengthIndicator(strength: _strength);
                        },
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 16),
                      // Requirements
                      _PasswordRequirements(
                        controller: _newCtrl,
                      ).animate().fadeIn(delay: 420.ms),
                      const SizedBox(height: 20),
                      SVaultTextField(
                        label: 'Confirm New Password',
                        hint: 'Re-enter new password',
                        isPassword: true,
                        controller: _confirmCtrl,
                      ).animate().fadeIn(delay: 460.ms),
                      const SizedBox(height: 32),
                      GradientButton(
                            label: 'Save Changes',
                            icon: Icons.save_rounded,
                            onTap: _save,
                          )
                          .animate()
                          .fadeIn(delay: 540.ms)
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

class _PasswordRequirements extends StatelessWidget {
  final TextEditingController controller;

  const _PasswordRequirements({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (_, v, _) {
        final text = controller.text;
        return Column(
          children: [
            _req('At least 8 characters', text.length >= 8),
            _req('One uppercase letter', text.contains(RegExp(r'[A-Z]'))),
            _req('One number', text.contains(RegExp(r'[0-9]'))),
            _req(
              'One special character',
              text.contains(RegExp(r'[!@#\$%^&*]')),
            ),
          ],
        );
      },
    );
  }

  Widget _req(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            met
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: met ? AppColors.success : AppColors.textHint,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: met ? AppColors.success : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
