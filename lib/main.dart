import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_master_password_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/password_list_screen.dart';
import 'screens/add_password_screen.dart';
import 'screens/view_password_screen.dart';
import 'screens/export_passwords_screen.dart';
import 'screens/import_passwords_screen.dart';
import 'screens/documents_list_screen.dart';
import 'screens/upload_document_screen.dart';
import 'screens/export_documents_screen.dart';
import 'screens/import_documents_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/change_master_password_screen.dart';
import 'screens/backup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce dark status bar for immersive experience
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Portrait only for mobile-first design
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SecureVaultApp());
}

class SecureVaultApp extends StatelessWidget {
  const SecureVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureVault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/create-master': (context) => const CreateMasterPasswordScreen(),
        '/dashboard': (context) => const MainNavigationScreen(),
        '/passwords': (context) => const PasswordListScreen(),
        '/add-password': (context) => const AddPasswordScreen(),
        '/view-password': (context) => const ViewPasswordScreen(),
        '/export-passwords': (context) => const ExportPasswordsScreen(),
        '/import-passwords': (context) => const ImportPasswordsScreen(),
        '/documents': (context) => const DocumentsListScreen(),
        '/upload-document': (context) => const UploadDocumentScreen(),
        '/export-documents': (context) => const ExportDocumentsScreen(),
        '/import-documents': (context) => const ImportDocumentsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/change-master-password': (context) => const ChangeMasterPasswordScreen(),
        '/backup': (context) => const BackupScreen(),
      },
    );
  }
}
