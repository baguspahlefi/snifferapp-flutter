import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io' as io;
import 'package:flutter_application_1/models/noteModel.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static const String databaseName = 'database.db';
  static const int versionNumber = 1;
  static const String tableNotes = 'Notes';

  // Tambahkan kolom untuk image path
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colDescription = 'description';
  static const String colImagePath = 'imagePath'; // Kolom baru untuk path gambar

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, databaseName);
    var db = await openDatabase(
      path, 
      version: versionNumber, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Tambahkan handler untuk upgrade database
    );
    return db;
  }

  // Modifikasi onCreate untuk menambahkan kolom imagePath
  _onCreate(Database db, int intVersion) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS $tableNotes (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colTitle TEXT NOT NULL,
        $colDescription TEXT,
        $colImagePath TEXT
      )
    """);
  }

  // Tambahkan method untuk handle upgrade database
  _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      // Tambahkan kolom imagePath jika belum ada
      await db.execute("ALTER TABLE $tableNotes ADD COLUMN $colImagePath TEXT;");
    }
  }

  Future<List<NoteModel>> getAll() async {
    final db = await database;
    final result = await db.query(tableNotes, orderBy: '$colId ASC');
    return result.map((json) => NoteModel.fromJson(json)).toList();
  }

  Future<NoteModel> read(int id) async {
    final db = await database;
    final maps = await db.query(
      tableNotes,
      where: '$colId = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return NoteModel.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<void> insert(NoteModel note) async {
    final db = await database;
    
    // Jika ada gambar, copy ke direktori aplikasi
    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      final fileName = note.imagePath!.split('/').last;
      final directory = await getApplicationDocumentsDirectory();
      final newPath = join(directory.path, 'note_images', fileName);
      
      // Buat direktori jika belum ada
      await io.Directory(join(directory.path, 'note_images'))
          .create(recursive: true);
      
      // Copy file ke direktori aplikasi
      await io.File(note.imagePath!).copy(newPath);
      
      // Update path gambar ke lokasi baru
      note = note.copyWith(imagePath: newPath);
    }

    await db.insert(
      tableNotes, 
      note.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  Future<int> update(NoteModel note) async {
    final db = await database;

    // Handle pembaruan gambar
    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      final oldNote = await read(note.id!);
      if (oldNote.imagePath != note.imagePath) {
        // Hapus gambar lama jika ada
        if (oldNote.imagePath != null) {
          final oldFile = io.File(oldNote.imagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        // Copy gambar baru ke direktori aplikasi
        final fileName = note.imagePath!.split('/').last;
        final directory = await getApplicationDocumentsDirectory();
        final newPath = join(directory.path, 'note_images', fileName);
        
        await io.Directory(join(directory.path, 'note_images'))
            .create(recursive: true);
        
        await io.File(note.imagePath!).copy(newPath);
        note = note.copyWith(imagePath: newPath);
      }
    }

    return await db.update(
      tableNotes, 
      note.toJson(),
      where: '$colId = ?',
      whereArgs: [note.id]
    );
  }

  Future<void> delete(int id) async {
    final db = await database;
    try {
      // Hapus gambar terkait jika ada
      final note = await read(id);
      if (note.imagePath != null) {
        final file = io.File(note.imagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await db.delete(
        tableNotes,
        where: "$colId = ?",
        whereArgs: [id]
      );
    } catch (err) {
      debugPrint("Something went wrong when deleting an item: $err");
    }
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}