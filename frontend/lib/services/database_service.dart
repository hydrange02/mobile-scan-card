import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  
  // In production, use a secure key storage like flutter_secure_storage
  final _key = encrypt.Key.fromUtf8('a-very-secret-32-character-key!!');
  final _iv = encrypt.IV.fromLength(16);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'wallet.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE cards(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, encryptedData TEXT, createdAt TEXT)',
        );
      },
    );
  }

  Future<void> saveCard(String name, String rawData) async {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(rawData, iv: _iv);
    
    final db = await database;
    await db.insert('cards', {
      'name': name,
      'encryptedData': encrypted.base64,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getCards() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cards', orderBy: 'createdAt DESC');
    
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    
    return maps.map((row) {
      try {
        final decrypted = encrypter.decrypt64(row['encryptedData'] as String, iv: _iv);
        return {
          'id': row['id'],
          'name': row['name'],
          'data': decrypted,
          'createdAt': row['createdAt']
        };
      } catch (e) {
        return {'id': row['id'], 'name': row['name'], 'error': 'Decryption failed'};
      }
    }).toList();
  }

  Future<void> deleteCard(int id) async {
    final db = await database;
    await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCardName(int id, String newName) async {
    final db = await database;
    await db.update('cards', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }
}
