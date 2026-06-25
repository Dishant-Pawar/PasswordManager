import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';

class CreateMasterPasswordScreen extends StatefulWidget {
  const CreateMasterPasswordScreen({super.key});

  @override
  State<CreateMasterPasswordScreen> createState() =>
      _CreateMasterPasswordScreenState();
}

class _CreateMasterPasswordScreenState
    extends State<CreateMasterPasswordScreen> {
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  final _hintController = TextEditingController();

  @override
  void dispose() {
    _passController.dispose();
    _confirmController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  void _createVault() async {
    final password = _passController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a master password.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (password.length < 8 ||
        !password.contains(RegExp(r'[A-Z]')) ||
        !password.contains(RegExp(r'[0-9]')) ||
        !password.contains(RegExp(r'[!@#\$%^&*]'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password does not meet requirements.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await DatabaseHelper.instance.createAndOpenDatabase(password);

    final hint = _hintController.text.trim();
    if (hint.isNotEmpty) {
      await SettingsService.instance.saveSetting('password_hint', hint);
    }

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                // Header
                Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Master',
                              style: GoogleFonts.poppins(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Password',
                              style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideX(begin: -0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  'This password encrypts all your data.\nNever stored — only you know it.',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 32),
                // Warning card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'If you forget this password, your data cannot be recovered.',
                          style: GoogleFonts.poppins(
                            color: AppColors.warning,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 28),
                SVaultTextField(
                  label: 'Master Password *',
                  hint: 'Enter a strong password',
                  isPassword: true,
                  controller: _passController,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
                ValueListenableBuilder(
                  valueListenable: _passController,
                  builder: (_, value, _) {
                    final text = value.text;
                    double s = 0;
                    if (text.length >= 8) s += 0.25;
                    if (text.contains(RegExp(r'[A-Z]'))) s += 0.25;
                    if (text.contains(RegExp(r'[0-9]'))) s += 0.25;
                    if (text.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.25;
                    return PasswordStrengthIndicator(strength: s);
                  },
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 20),
                // Requirements
                _PasswordRequirements(controller: _passController),
                const SizedBox(height: 20),
                SVaultTextField(
                  label: 'Confirm Password *',
                  hint: 'Re-enter your password',
                  isPassword: true,
                  controller: _confirmController,
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 20),
                SVaultTextField(
                  label: 'Password Hint (Optional)',
                  hint: 'Enter a reminder for your password',
                  controller: _hintController,
                ).animate().fadeIn(delay: 550.ms),
                const SizedBox(height: 36),
                GradientButton(
                  label: 'Create Vault',
                  icon: Icons.lock_rounded,
                  onTap: _createVault,
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 24),
              ],
            ),
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
