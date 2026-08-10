import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'wallet.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cards(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cardName TEXT,
            cardNumber TEXT,
            isDefault INTEGER
          )
        ''');
      },
    );
  }

  Future<void> insertCard(Map<String, dynamic> card) async {
    final db = await database;
    await db.insert('cards', card, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCards() async {
    final db = await database;
    return await db.query('cards');
  }

  Future<void> deleteCard(int id) async {
    final db = await database;
    await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }
}
