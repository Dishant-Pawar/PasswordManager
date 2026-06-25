import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _canUseBiometrics = false;
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final settings = await SettingsService.instance.loadSettings();
    final enabled = settings['biometric_enabled'] as bool? ?? false;
    
    if (enabled) {
      try {
        final bool canCheck = await _auth.canCheckBiometrics;
        final bool isSupported = await _auth.isDeviceSupported();
        final hasSavedKey = await _secureStorage.containsKey(key: 'db_derived_key');

        if (canCheck && isSupported && hasSavedKey) {
          setState(() {
            _canUseBiometrics = true;
          });
          // Auto-trigger biometric prompt after layout builds
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _authenticateWithBiometrics();
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!_canUseBiometrics) return;

    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to unlock your SecureVault',
        biometricOnly: true,
      );

      if (didAuthenticate) {
        setState(() => _loading = true);
        final derivedKey = await _secureStorage.read(key: 'db_derived_key');
        if (derivedKey != null) {
          final isOpened = await DatabaseHelper.instance.openDatabaseWithDerivedKey(derivedKey);
          if (mounted) {
            setState(() => _loading = false);
            if (isOpened) {
              Navigator.pushReplacementNamed(context, '/dashboard');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to open database with saved key. Please enter password.', style: GoogleFonts.poppins()),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No biometric key found. Please enter password.', style: GoogleFonts.poppins()),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication error: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _unlock() async {
    final password = _controller.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your master password.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final isCorrect = await DatabaseHelper.instance.verifyAndOpenDatabase(password);
    
    if (mounted) {
      setState(() => _loading = false);
      if (isCorrect) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incorrect master password. Access denied.', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showForgotDialog() async {
    final settings = await SettingsService.instance.loadSettings();
    final hint = settings['password_hint'] as String? ?? '';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Forgot Password',
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
                'Because SecureVault uses zero-knowledge end-to-end encryption, we do not store your master password and cannot reset it or email it to you.',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Password Hint:',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Text(
                  hint.isNotEmpty ? hint : 'No password hint was set up.',
                  style: GoogleFonts.poppins(
                    color: hint.isNotEmpty ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: hint.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    fontStyle: hint.isNotEmpty ? null : FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'If you cannot remember your password and have no backup, you must reset your vault to create a new one. This will permanently delete all your stored data.',
                style: GoogleFonts.poppins(
                  color: AppColors.error,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showResetConfirmDialog();
              },
              child: Text(
                'Reset Vault',
                style: GoogleFonts.poppins(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _VaultResetDialog(
          onConfirm: _performVaultReset,
        );
      },
    );
  }

  void _performVaultReset() async {
    setState(() => _loading = true);

    try {
      await DatabaseHelper.instance.resetVault();
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault reset successful. All data cleared.', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/create-master', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset vault: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Logo
                Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    )
                    .animate()
                    .scale(
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.6, 0.6),
                    )
                    .fadeIn(),
                const SizedBox(height: 28),
                Text(
                  'Welcome Back',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 6),
                Text(
                  'Enter your master password',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 48),
                SVaultTextField(
                  label: 'Master Password',
                  hint: 'Enter your master password',
                  isPassword: true,
                  controller: _controller,
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotDialog,
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 20),
                _loading
                    ? Container(
                        height: 56,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      )
                    : GradientButton(
                            label: 'Unlock Vault',
                            icon: Icons.lock_open_rounded,
                            onTap: _unlock,
                          )
                          .animate()
                          .fadeIn(delay: 500.ms)
                          .slideY(begin: 0.2, end: 0),
                if (_canUseBiometrics) ...[
                  const SizedBox(height: 32),
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or use fingerprint',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 24),
                  // Fingerprint button
                  GestureDetector(
                        onTap: _authenticateWithBiometrics,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.fingerprint_rounded,
                            color: AppColors.primary,
                            size: 38,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 700.ms)
                      .scale(begin: const Offset(0.8, 0.8)),
                ],
                const Spacer(),
                // Not registered?
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "New user? ",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/create-master'),
                      child: Text(
                        'Create Master Password',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 800.ms),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VaultResetDialog extends StatefulWidget {
  final VoidCallback onConfirm;

  const _VaultResetDialog({required this.onConfirm});

  @override
  State<_VaultResetDialog> createState() => _VaultResetDialogState();
}

class _VaultResetDialogState extends State<_VaultResetDialog> {
  final _confirmController = TextEditingController();
  bool _isResetButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final val = _confirmController.text.trim();
    setState(() {
      _isResetButtonEnabled = val == 'RESET';
    });
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
          const SizedBox(width: 8),
          Text(
            'Reset Vault?',
            style: GoogleFonts.poppins(
              color: AppColors.error,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action is irreversible. All passwords, secrets, documents, and profile photos will be permanently deleted from this device.',
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'To confirm, type "RESET" below:',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SVaultTextField(
            label: 'Confirm resetting',
            hint: 'Type RESET',
            controller: _confirmController,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: _isResetButtonEnabled
              ? () {
                  Navigator.pop(context);
                  widget.onConfirm();
                }
              : null,
          child: Text(
            'DELETE EVERYTHING',
            style: GoogleFonts.poppins(
              color: _isResetButtonEnabled ? AppColors.error : AppColors.textHint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
