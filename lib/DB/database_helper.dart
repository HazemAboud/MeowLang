import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:meow_lang/models/historyRecord.dart';
import 'package:meow_lang/models/translation.dart';
import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('meow_lang.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Drop old tables to recreate them with new schema
    await db.execute('DROP TABLE IF EXISTS users');
    await db.execute('DROP TABLE IF EXISTS cats');
    await db.execute('DROP TABLE IF EXISTS translations');
    await db.execute('DROP TABLE IF EXISTS history');
    await _createDB(db, newVersion);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE users (
  userId INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  email TEXT,
  password TEXT,
  regDate TEXT
)
''');

    await db.execute('''
CREATE TABLE cats (
  catId INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  breed TEXT,
  gender TEXT,
  age INTEGER
)
''');

    await db.execute('''
CREATE TABLE translations (
  translationId INTEGER PRIMARY KEY AUTOINCREMENT,
  audioPath TEXT,
  className TEXT,
  confidence REAL,
  datetime TEXT
)
''');

    await db.execute('''
CREATE TABLE history (
  id TEXT PRIMARY KEY,
  textTranslation TEXT,
  translationId INTEGER,
  catId INTEGER
)
''');
  }

  // User Functions
  Future<int> registerUser(String name, String email, String password) async {
    final db = await instance.database;
    return await db.insert('users', {
      'name': name,
      'email': email,
      'password': password,
      'regDate': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertUser(User user) async {
    final db = await instance.database;
    await db.insert('users', user.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<User?> getUser() async {
    final db = await instance.database;
    final maps = await db.query('users', limit: 1);

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  Future<void> deleteUser(int id) async {
    final db = await instance.database;
    await db.delete(
      'users',
      where: 'userId = ?',
      whereArgs: [id],
    );
  }

  // Cat Functions
  Future<void> insertCat(Cat cat) async {
    final db = await instance.database;
    final map = cat.toJson();
    // Ensure key matches table column 'catId' if model uses 'CatId'
    if (map.containsKey('CatId')) {
      map['catId'] = map['CatId'];
      map.remove('CatId');
    }
    await db.insert('cats', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Cat>> getCats() async {
    final db = await instance.database;
    final result = await db.query('cats');

    return result.map((json) {
      final map = Map<String, dynamic>.from(json);
      // Ensure key matches model expectation 'CatId'
      if (map.containsKey('catId')) {
        map['CatId'] = map['catId'];
      }
      return Cat.fromJson(map);
    }).toList();
  }

  Future<int> updateCat(Cat cat) async {
    final db = await instance.database;
    final map = cat.toJson();
    if (map.containsKey('CatId')) {
      map['catId'] = map['CatId'];
      map.remove('CatId');
    }
    return await db.update('cats', map,
        where: 'catId = ?', whereArgs: [cat.catId]);
  }

  Future<void> deleteCat(int id) async {
    final db = await instance.database;
    await db.delete(
      'cats',
      where: 'catId = ?',
      whereArgs: [id],
    );
  }

  // Translation Functions
  Future<int> insertTranslation(Translation translation) async {
    final db = await instance.database;
    return await db.insert('translations', {
      'audioPath': translation.audioPath,
      'className': translation.className,
      'confidence': translation.confidence,
      'datetime': translation.dateTime?.toIso8601String(),
    });
  }

  // History Functions
  Future<void> insertHistory(HistoryRecord record) async {
    final db = await instance.database;

    await db.insert(
      'history',
      {
        'id': record.id,
        'textTranslation': record.textTranslation,
        'translationId': record.translationId,
        'catId': record.catId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HistoryRecord>> readAllHistory() async {
    final db = await instance.database;
    // Join with cats table to get cat details
    final result = await db.rawQuery('''
      SELECT h.*, t.*, c.name as cat_name, c.breed as cat_breed, c.gender as cat_gender, c.age as cat_age 
      FROM history h 
      LEFT JOIN cats c ON h.catId = c.catId 
      LEFT JOIN translations t ON h.translationId = t.translationId
      ORDER BY t.datetime DESC
    ''');

    return result.map((json) {
      final dateTimeStr = json['datetime'] as String?;
      final translation = Translation(
        id: json['translationId'] as int?,
        audioPath: json['audioPath'] as String?,
        className: json['className'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        dateTime: dateTimeStr != null ? DateTime.tryParse(dateTimeStr) : null,
      );

      Cat? cat;
      if (json['catId'] != null) {
        cat = Cat(
          catId: json['catId'] as int?,
          name: json['cat_name'] as String? ?? 'Unknown',
          breed: json['cat_breed'] as String? ?? 'Unknown',
          gender: json['cat_gender'] as String? ?? 'Unknown',
          age: json['cat_age'] as int? ?? 0,
        );
      }

      return HistoryRecord(
        id: json['id'] as String?,
        textTranslation: json['textTranslation'] as String?,
        translationId: json['translationId'] as int?,
        catId: json['catId'] as int?,
        translation: translation,
        cat: cat,
      );
    }).toList();
  }

  Future<void> deleteHistory(String id) async {
    final db = await instance.database;
    await db.delete(
      'history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}