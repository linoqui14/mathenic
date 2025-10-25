import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/math_result.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mathenic.db');
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
    await db.execute('''
      CREATE TABLE results (
        id TEXT PRIMARY KEY,
        question TEXT NOT NULL,
        solution TEXT NOT NULL,
        answer TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        subject TEXT NOT NULL
      )
    ''');
  }

  Future<String> saveImageToStorage(String base64Image, String resultId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/images');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final imagePath = '${imagesDir.path}/$resultId.png';
    final imageFile = File(imagePath);

    final bytes = base64Decode(base64Image);
    await imageFile.writeAsBytes(bytes);

    return imagePath;
  }

  Future<int> insertResult(MathResult result) async {
    final db = await database;
    return await db.insert(
      'results',
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MathResult>> getAllResults() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'results',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => MathResult.fromMap(maps[i]));
  }

  Future<int> deleteResult(String id) async {
    final db = await database;

    // Delete the image file
    final results = await db.query('results', where: 'id = ?', whereArgs: [id]);
    if (results.isNotEmpty) {
      final imagePath = results.first['imagePath'] as String;
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    }

    return await db.delete('results', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearAllResults() async {
    final db = await database;

    // Delete all image files
    final results = await db.query('results');
    for (var result in results) {
      final imagePath = result['imagePath'] as String;
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    }

    return await db.delete('results');
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}