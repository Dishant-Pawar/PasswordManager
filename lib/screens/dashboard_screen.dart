import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

import '../services/database_helper.dart';
import '../models/password_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _passwordCount = 0;
  int _documentCount = 0;
  List<PasswordItem> _recentPasswords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbHelper = DatabaseHelper.instance;
    final passwords = await dbHelper.readAllPasswords();
    final documents = await dbHelper.readAllDocuments();

    setState(() {
      _passwordCount = passwords.length;
      _documentCount = documents.length;
      _recentPasswords = passwords.take(3).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Good Morning,',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'John Doe 👋',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 20),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search passwords, documents...',
                            hintStyle: GoogleFonts.poppins(
                              color: AppColors.textHint,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                            suffixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 150.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 24),
                      // Stats grid
                      GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.4,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.pushNamed(context, '/passwords');
                                  _loadData();
                                },
                                child: StatCard(
                                  value: _passwordCount.toString(),
                                  label: 'Passwords',
                                  icon: Icons.key_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.pushNamed(context, '/documents');
                                  _loadData();
                                },
                                child: StatCard(
                                  value: _documentCount.toString(),
                                  label: 'Documents',
                                  icon: Icons.folder_rounded,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 24),
                      // Recent activity
                      SectionHeader(
                        title: 'Recent Activity',
                        action: 'View all',
                        onAction: () async {
                          await Navigator.pushNamed(context, '/passwords');
                          _loadData();
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_recentPasswords.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No recent activity',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._recentPasswords.asMap().entries.map(
                          (e) {
                            final password = e.value;
                            return PasswordListTile(
                                  title: password.title.isNotEmpty ? password.title : 'Unnamed',
                                  username: password.username.isNotEmpty ? password.username : 'No username',
                                  initial: password.title.isNotEmpty ? password.title[0].toUpperCase() : '?',
                                  color: AppColors.primary, // Using primary color for all for now
                                  onTap: () async {
                                    await Navigator.pushNamed(
                                      context,
                                      '/view-password',
                                      arguments: password,
                                    );
                                    _loadData();
                                  },
                                )
                                .animate()
                                .fadeIn(
                                  delay: Duration(
                                    milliseconds: 600 + e.key * 100,
                                  ),
                                )
                                .slideX(begin: 0.1, end: 0);
                          }
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 0, context: context),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add-password');
          _loadData();
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final BuildContext context;

  const _BottomNav({required this.currentIndex, required this.context});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
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
                currentIndex,
                () => Navigator.pushReplacementNamed(context, '/dashboard'),
              ),
              _navItem(
                Icons.folder_rounded,
                'Documents',
                1,
                currentIndex,
                () => Navigator.pushNamed(context, '/documents'),
              ),
              const SizedBox(width: 48),
              _navItem(
                Icons.backup_rounded,
                'Backup',
                2,
                currentIndex,
                () => Navigator.pushNamed(context, '/backup'),
              ),
              _navItem(
                Icons.settings_rounded,
                'Settings',
                3,
                currentIndex,
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
    int index,
    int current,
    VoidCallback onTap,
  ) {
    final isActive = index == current;
    return GestureDetector(
      onTap: onTap,
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
