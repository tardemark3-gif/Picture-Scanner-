import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/scan_record.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databaseFolder = await getDatabasesPath();
    final databasePath = path.join(databaseFolder, 'picture_scanner.db');

    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE scan_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT NOT NULL,
            picture_path TEXT NOT NULL,
            picture_filename TEXT NOT NULL,
            scanned_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<int> insertRecord(ScanRecord record) async {
    final db = await database;

    return db.insert(
      'scan_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScanRecord>> getRecords() async {
    final db = await database;

    final rows = await db.query('scan_records', orderBy: 'id DESC');

    return rows.map(ScanRecord.fromMap).toList();
  }

  Future<int> countPicturesForBarcode(String barcode) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM scan_records
      WHERE barcode = ?
      ''',
      [barcode],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteRecord(int id) async {
    final db = await database;

    await db.delete('scan_records', where: 'id = ?', whereArgs: [id]);
  }
}
