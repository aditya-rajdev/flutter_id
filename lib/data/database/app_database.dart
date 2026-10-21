
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, 'id_card_studio.db');

    return openDatabase(
      databasePath,
      version: DatabaseSchema.version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        for (final statement in DatabaseSchema.createStatements) {
          await db.execute(statement);
        }

        for (final statement in DatabaseSchema.createIndexes) {
          await db.execute(statement);
        }
      },
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
