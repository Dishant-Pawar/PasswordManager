import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = true;
  bool _biometric = true;
  bool _autoBackup = false;

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
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
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
                                  'John Doe',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'john@example.com',
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
                                onChanged: (v) =>
                                    setState(() => _autoBackup = v),
                                activeThumbColor: AppColors.primary,
                              ),
                            ),
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
                                onChanged: (v) =>
                                    setState(() => _biometric = v),
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
                              title: 'Dark Mode',
                              icon: Icons.dark_mode_rounded,
                              iconColor: AppColors.accent,
                              trailing: Switch(
                                value: _darkMode,
                                onChanged: (v) => setState(() => _darkMode = v),
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
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
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
              _navItem(
                Icons.folder_rounded,
                'Documents',
                false,
                () => Navigator.pushNamed(context, '/documents'),
              ),
              const SizedBox(width: 48),
              _navItem(
                Icons.backup_rounded,
                'Backup',
                false,
                () => Navigator.pushNamed(context, '/backup'),
              ),
              _navItem(Icons.settings_rounded, 'Settings', true, () {}),
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
