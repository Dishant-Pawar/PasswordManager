import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_helper.dart';
import '../models/password_item.dart';

class AddPasswordScreen extends StatefulWidget {
  const AddPasswordScreen({super.key});

  @override
  State<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
  final _titleCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _backupCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ── Generator state ──────────────────────────────────────────────────────────
  bool _showGenerator = false;
  double _genLength = 16;
  bool _useUpper = true;
  bool _useLower = true;
  bool _useNumbers = true;
  bool _useSymbols = true;
  String _generatedPassword = '';

  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _numbers = '0123456789';
  static const _symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }



  PasswordItem? _existingItem;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is PasswordItem) {
        _existingItem = args;
        _titleCtrl.text = _existingItem!.title;
        _usernameCtrl.text = _existingItem!.username;
        _passwordCtrl.text = _existingItem!.password;
        _notesCtrl.text = _existingItem!.notes;
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _backupCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    final title = _titleCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        )
      );
      return;
    }

    String combinedNotes = _notesCtrl.text.trim();
    if (_backupCtrl.text.trim().isNotEmpty) {
      combinedNotes += '\n\nBackup Codes:\n${_backupCtrl.text.trim()}';
    }

    final item = PasswordItem(
      id: _existingItem?.id,
      title: title,
      username: username,
      password: password,
      notes: combinedNotes.trim(),
      createdAt: _existingItem?.createdAt ?? DateTime.now(),
      category: _existingItem?.category ?? 'General',
    );

    if (_existingItem == null) {
      await DatabaseHelper.instance.createPassword(item);
    } else {
      await DatabaseHelper.instance.updatePassword(item);
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _generatePassword() {
    String charset = '';
    if (_useUpper) charset += _upper;
    if (_useLower) charset += _lower;
    if (_useNumbers) charset += _numbers;
    if (_useSymbols) charset += _symbols;

    if (charset.isEmpty) {
      setState(() => _generatedPassword = '');
      return;
    }

    final rand = Random.secure();
    final length = _genLength.toInt();

    // Ensure at least one char from each selected group
    List<String> required = [];
    if (_useUpper) required.add(_upper[rand.nextInt(_upper.length)]);
    if (_useLower) required.add(_lower[rand.nextInt(_lower.length)]);
    if (_useNumbers) required.add(_numbers[rand.nextInt(_numbers.length)]);
    if (_useSymbols) required.add(_symbols[rand.nextInt(_symbols.length)]);

    List<String> rest = List.generate(
      length - required.length,
      (_) => charset[rand.nextInt(charset.length)],
    );

    final all = [...required, ...rest]..shuffle(rand);
    setState(() => _generatedPassword = all.join());
  }

  void _useGenerated() {
    _passwordCtrl.text = _generatedPassword;
    setState(() => _showGenerator = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password applied!', style: GoogleFonts.poppins()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyGenerated() {
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password copied!', style: GoogleFonts.poppins()),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  double _calcStrength(String value) {
    double s = 0;
    if (value.length >= 8) s += 0.25;
    if (value.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (value.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (value.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.25;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _existingItem == null ? 'Add Password' : 'Edit Password',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _savePassword,
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

              // ── Body ────────────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SVaultTextField(
                        label: 'Website / App Name',
                        hint: 'e.g. Google, Netflix',
                        controller: _titleCtrl,
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 20),
                      SVaultTextField(
                        label: 'Username *',
                        hint: 'Enter username or email',
                        controller: _usernameCtrl,
                        keyboardType: TextInputType.emailAddress,
                      ).animate().fadeIn(delay: 280.ms),
                      const SizedBox(height: 20),

                      // ── Password field + generator toggle ─────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Password *',
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _showGenerator = !_showGenerator,
                                  );
                                  if (!_showGenerator) _generatePassword();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        color: AppColors.primary,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _showGenerator
                                            ? 'Hide Generator'
                                            : 'Generate',
                                        style: GoogleFonts.poppins(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SVaultTextField(
                            label: '',
                            hint: 'Enter password',
                            isPassword: true,
                            controller: _passwordCtrl,
                          ),
                        ],
                      ).animate().fadeIn(delay: 360.ms),

                      const SizedBox(height: 12),

                      // ── Strength indicator ─────────────────────────────────
                      ValueListenableBuilder(
                        valueListenable: _passwordCtrl,
                        builder: (_, v, _) {
                          return PasswordStrengthIndicator(
                            strength: _calcStrength(_passwordCtrl.text),
                          );
                        },
                      ).animate().fadeIn(delay: 380.ms),

                      const SizedBox(height: 12),

                      // ── Password Generator Panel ───────────────────────────
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        child: _showGenerator
                            ? _PasswordGeneratorPanel(
                                generatedPassword: _generatedPassword,
                                length: _genLength,
                                useUpper: _useUpper,
                                useLower: _useLower,
                                useNumbers: _useNumbers,
                                useSymbols: _useSymbols,
                                onLengthChanged: (v) {
                                  setState(() => _genLength = v);
                                  _generatePassword();
                                },
                                onUpperChanged: (v) {
                                  setState(() => _useUpper = v);
                                  _generatePassword();
                                },
                                onLowerChanged: (v) {
                                  setState(() => _useLower = v);
                                  _generatePassword();
                                },
                                onNumbersChanged: (v) {
                                  setState(() => _useNumbers = v);
                                  _generatePassword();
                                },
                                onSymbolsChanged: (v) {
                                  setState(() => _useSymbols = v);
                                  _generatePassword();
                                },
                                onRefresh: _generatePassword,
                                onCopy: _copyGenerated,
                                onUse: _useGenerated,
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 20),

                      // ── Backup codes ───────────────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup Codes (Optional)',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _backupCtrl,
                            style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Add backup codes, one per line',
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 440.ms),
                      const SizedBox(height: 20),

                      // ── Notes ──────────────────────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes (Optional)',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesCtrl,
                            style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Add notes',
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 32),

                      GradientButton(
                            label: _existingItem == null ? 'Save Password' : 'Update Password',
                            icon: Icons.save_rounded,
                            onTap: _savePassword,
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

// ── Password Generator Panel ──────────────────────────────────────────────────
class _PasswordGeneratorPanel extends StatelessWidget {
  final String generatedPassword;
  final double length;
  final bool useUpper;
  final bool useLower;
  final bool useNumbers;
  final bool useSymbols;
  final ValueChanged<double> onLengthChanged;
  final ValueChanged<bool> onUpperChanged;
  final ValueChanged<bool> onLowerChanged;
  final ValueChanged<bool> onNumbersChanged;
  final ValueChanged<bool> onSymbolsChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCopy;
  final VoidCallback onUse;

  const _PasswordGeneratorPanel({
    required this.generatedPassword,
    required this.length,
    required this.useUpper,
    required this.useLower,
    required this.useNumbers,
    required this.useSymbols,
    required this.onLengthChanged,
    required this.onUpperChanged,
    required this.onLowerChanged,
    required this.onNumbersChanged,
    required this.onSymbolsChanged,
    required this.onRefresh,
    required this.onCopy,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.accent.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Password Generator',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Generated password display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          generatedPassword.isEmpty
                              ? 'Select at least one option'
                              : generatedPassword,
                          style: GoogleFonts.robotoMono(
                            color: generatedPassword.isEmpty
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Refresh
                      GestureDetector(
                        onTap: onRefresh,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Copy
                      GestureDetector(
                        onTap: onCopy,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            color: AppColors.accent,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Length slider
                Row(
                  children: [
                    Text(
                      'Length',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${length.toInt()}',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.15),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: length,
                    min: 8,
                    max: 32,
                    divisions: 24,
                    onChanged: onLengthChanged,
                  ),
                ),

                const SizedBox(height: 8),

                // Character toggles
                Text(
                  'Include',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToggleChip(
                      label: 'A-Z',
                      active: useUpper,
                      onChanged: onUpperChanged,
                    ),
                    _ToggleChip(
                      label: 'a-z',
                      active: useLower,
                      onChanged: onLowerChanged,
                    ),
                    _ToggleChip(
                      label: '0-9',
                      active: useNumbers,
                      onChanged: onNumbersChanged,
                    ),
                    _ToggleChip(
                      label: '!@#',
                      active: useSymbols,
                      onChanged: onSymbolsChanged,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Use this password button
                GestureDetector(
                  onTap: onUse,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Use this Password',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle Chip ───────────────────────────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final ValueChanged<bool> onChanged;

  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.robotoMono(
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
