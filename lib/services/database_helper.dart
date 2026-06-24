import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/password_item.dart';
import '../models/document_item.dart';
import 'auto_backup_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

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

  // ==========================================
  // Passwords CRUD
  // ==========================================

  Future<PasswordItem> createPassword(PasswordItem password) async {
    final db = await instance.database;
    final id = await db.insert('passwords', password.toMap());
    final result = password.copyWith(id: id);
    unawaited(AutoBackupHelper.triggerAutoBackup());
    return result;
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
  // Documents CRUD
  // ==========================================

  Future<DocumentItem> createDocument(DocumentItem document) async {
    final db = await instance.database;
    final id = await db.insert('documents', document.toMap());
    final result = document.copyWith(id: id);
    unawaited(AutoBackupHelper.triggerAutoBackup());
    return result;
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
    final db = await instance.database;
    db.close();
  }
}
