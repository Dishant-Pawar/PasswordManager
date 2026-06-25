import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'documents_list_screen.dart';
import 'backup_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // GlobalKeys to trigger refresh on sub-screens
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<DocumentsListScreenState> _documentsKey = GlobalKey<DocumentsListScreenState>();
  final GlobalKey<BackupScreenState> _backupKey = GlobalKey<BackupScreenState>();
  final GlobalKey<SettingsScreenState> _settingsKey = GlobalKey<SettingsScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(key: _dashboardKey),
      DocumentsListScreen(key: _documentsKey),
      BackupScreen(key: _backupKey),
      SettingsScreen(key: _settingsKey),
    ];
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    // Trigger loads/reloads on tab switch
    if (index == 0) {
      _dashboardKey.currentState?.reload();
    } else if (index == 1) {
      _documentsKey.currentState?.reload();
    } else if (index == 2) {
      _backupKey.currentState?.reload();
    } else if (index == 3) {
      _settingsKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFab = _currentIndex == 0 || _currentIndex == 1;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
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
                ),
                _navItem(
                  Icons.folder_rounded,
                  'Documents',
                  1,
                ),
                const SizedBox(width: 48), // Spacer for center docked floating action button
                _navItem(
                  Icons.backup_rounded,
                  'Backup',
                  2,
                ),
                _navItem(
                  Icons.settings_rounded,
                  'Settings',
                  3,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () async {
                if (_currentIndex == 0) {
                  await Navigator.pushNamed(context, '/add-password');
                  _dashboardKey.currentState?.reload();
                } else if (_currentIndex == 1) {
                  await Navigator.pushNamed(context, '/upload-document');
                  _documentsKey.currentState?.reload();
                }
              },
              backgroundColor: AppColors.primary,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
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
