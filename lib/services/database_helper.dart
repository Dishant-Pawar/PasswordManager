import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/password_item.dart';
import '../models/document_item.dart';
import 'auto_backup_helper.dart';
import 'encryption_helper.dart';
import 'settings_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;
  static String? _dbPassword;

  DatabaseHelper._init();

  static void setDatabasePassword(String? password) {
    _dbPassword = password;
  }

  static String? get databasePassword => _dbPassword;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('securevault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      password: _dbPassword,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE passwords (
  id $idType,
  title $textType,
  username $textType,
  password $textType,
  url $textType,
  notes $textType,
  category $textType,
  createdAt $textType,
  updatedAt $textType
)
''');

    await db.execute('''
CREATE TABLE documents (
  id $idType,
  name $textType,
  filePath $textType,
  fileType $textType,
  sizeBytes $integerType,
  createdAt $textType
)
''');
  }

  Future<bool> verifyAndOpenDatabase(String masterPassword) async {
    final salt = await SettingsService.instance.loadSettings().then((s) => s['db_salt'] as String?);
    if (salt == null) return false;

    if (_database != null) {
      await close();
    }

    final derivedKey = await EncryptionHelper.deriveDatabaseKey(masterPassword, salt);
    _dbPassword = derivedKey;

    try {
      _database = await _initDB('securevault.db');
      // Test query to verify encryption key is correct (independent of table structures)
      await _database!.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      _dbPassword = null;
      _database = null;
      return false;
    }
  }

  Future<void> createAndOpenDatabase(String masterPassword) async {
    final random = Random.secure();
    final saltBytes = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
    final saltBase64 = base64Encode(saltBytes);

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'securevault.db');
    final file = File(path);

    final derivedKey = await EncryptionHelper.deriveDatabaseKey(masterPassword, saltBase64);

    if (await file.exists()) {
      Database? tempDb;
      bool isUnencrypted = false;
      try {
        tempDb = await openDatabase(path, version: 1);
        await tempDb.rawQuery('SELECT 1');
        isUnencrypted = true;
      } catch (e) {
        isUnencrypted = false;
      } finally {
        if (tempDb != null) {
          await tempDb.close();
        }
      }

      if (isUnencrypted) {
        final dbToRekey = await openDatabase(path, version: 1);
        try {
          await dbToRekey.rawQuery("PRAGMA rekey = '$derivedKey'");
          debugPrint('Successfully encrypted legacy unencrypted database.');
        } catch (e) {
          debugPrint('Failed to rekey unencrypted database: $e');
        } finally {
          await dbToRekey.close();
        }
      } else {
        if (_database != null) {
          await close();
        }
        await deleteDatabase(path);
        debugPrint('Deleted existing encrypted database to start fresh.');
      }
    }

    await SettingsService.instance.saveSetting('db_salt', saltBase64);

    if (_database != null) {
      await close();
    }

    _dbPassword = derivedKey;
    _database = await _initDB('securevault.db');
  }

  Future<bool> changeMasterPassword(String currentPassword, String newPassword) async {
    final salt = await SettingsService.instance.loadSettings().then((s) => s['db_salt'] as String?);
    if (salt == null) return false;

    final currentKey = await EncryptionHelper.deriveDatabaseKey(currentPassword, salt);
    if (currentKey != _dbPassword) {
      return false;
    }

    final newKey = await EncryptionHelper.deriveDatabaseKey(newPassword, salt);
    final db = await database;
    try {
      await db.rawQuery("PRAGMA rekey = '$newKey'");
      _dbPassword = newKey;
      return true;
    } catch (e) {
      debugPrint('Error rekeying database: $e');
      return false;
    }
  }

  // ==========================================
  // Passwords CRUD & Batch
  // ==========================================

  Future<PasswordItem> createPassword(PasswordItem password) async {
    final db = await instance.database;
    final id = await db.insert('passwords', password.toMap());
    final result = password.copyWith(id: id);
    unawaited(AutoBackupHelper.triggerAutoBackup());
    return result;
  }

  Future<void> importPasswords(List<PasswordItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      final existingMaps = await txn.query('passwords');
      final existingPasswords = existingMaps.map((map) => PasswordItem.fromMap(map)).toList();

      for (final item in items) {
        PasswordItem? match;
        for (final existing in existingPasswords) {
          if (existing.title.trim().toLowerCase() == item.title.trim().toLowerCase() &&
              existing.username.trim() == item.username.trim()) {
            match = existing;
            break;
          }
        }

        if (match != null) {
          await txn.update(
            'passwords',
            item.toMap(),
            where: 'id = ?',
            whereArgs: [match.id],
          );
        } else {
          await txn.insert('passwords', item.toMap());
        }
      }
    });
    unawaited(AutoBackupHelper.triggerAutoBackup());
  }

  Future<PasswordItem?> readPassword(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'passwords',
      columns: ['id', 'title', 'username', 'password', 'url', 'notes', 'category', 'createdAt', 'updatedAt'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return PasswordItem.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<PasswordItem>> readAllPasswords() async {
    final db = await instance.database;
    final result = await db.query('passwords', orderBy: 'createdAt DESC');
    return result.map((json) => PasswordItem.fromMap(json)).toList();
  }

  Future<int> updatePassword(PasswordItem password) async {
    final db = await instance.database;
    final result = await db.update(
      'passwords',
      password.toMap(),
      where: 'id = ?',
      whereArgs: [password.id],
    );
    unawaited(AutoBackupHelper.triggerAutoBackup());
    return result;
  }

  Future<int> deletePassword(int id) async {
    final db = await instance.database;
    final result = await db.delete(
      'passwords',
      where: 'id = ?',
      whereArgs: [id],
    );
    unawaited(AutoBackupHelper.triggerAutoBackup());
    return result;
  }

  // ==========================================
  // Documents CRUD & Batch
  // ==========================================

  Future<DocumentItem> createDocument(DocumentItem document) async {
    final db = await instance.database;
    final id = await db.insert('documents', document.toMap());
    final result = document.copyWith(id: id);
    unawaited(AutoBackupHelper.triggerAutoBackup());
    return result;
  }

  Future<void> importDocuments(List<DocumentItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in items) {
        await txn.insert('documents', item.toMap());
      }
    });
    unawaited(AutoBackupHelper.triggerAutoBackup());
  }

  Future<DocumentItem?> readDocument(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'documents',
      columns: ['id', 'name', 'filePath', 'fileType', 'sizeBytes', 'createdAt'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return DocumentItem.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<DocumentItem>> readAllDocuments() async {
    final db = await instance.database;
    final result = await db.query('documents', orderBy: 'createdAt DESC');
    return result.map((json) => DocumentItem.fromMap(json)).toList();
  }

  Future<int> updateDocument(DocumentItem document) async {
    final db = await instance.database;
    final result = await db.update(
      'documents',
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
    unawaited(AutoBackupHelper.triggerAutoBackup());
    return result;
  }

  Future<int> deleteDocument(int id) async {
    final db = await instance.database;
    final result = await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    unawaited(AutoBackupHelper.triggerAutoBackup());
    return result;
  }

  Future close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> logout() async {
    await close();
    _dbPassword = null;
  }

  Future<void> resetVault() async {
    await close();
    _dbPassword = null;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'securevault.db');
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    final appDir = await getApplicationDocumentsDirectory();
    final savedDir = Directory(join(appDir.path, 'documents'));
    if (await savedDir.exists()) {
      await savedDir.delete(recursive: true);
    }

    final profileDir = Directory(join(appDir.path, 'profile_photos'));
    if (await profileDir.exists()) {
      await profileDir.delete(recursive: true);
    }

    final settingsFile = File(join(appDir.path, 'app_settings.json'));
    if (await settingsFile.exists()) {
      await settingsFile.delete();
    }
  }
}
