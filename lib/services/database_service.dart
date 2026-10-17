
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/guest.dart';
import '../models/import_result.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance =
      DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    final path = join(
      dbPath,
      'lolis_jose_guests.db',
    );

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE guests (
            code TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            adults INTEGER NOT NULL,
            children INTEGER NOT NULL,
            used INTEGER NOT NULL DEFAULT 0,
            checked_in_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_guests_name '
          'ON guests(name)',
        );
      },
    );
  }

  // Importar invitados iniciales desde JSON.
  // Solo se ejecuta cuando la tabla está vacía.
  Future<void> seedGuests() async {
    final db = await database;

    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM guests',
      ),
    ) ?? 0;

    if (count > 0) return;

    final jsonString = await rootBundle.loadString(
      'assets/data/guests.json',
    );

    final data =
        jsonDecode(jsonString) as Map<String, dynamic>;

    final guests = data.entries.map((entry) {
      return Guest.fromJson(
        entry.key,
        Map<String, dynamic>.from(entry.value as Map),
      );
    }).toList();

    await db.transaction((txn) async {
      for (final guest in guests) {
        await txn.insert(
          'guests',
          guest.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  // Obtener todos los invitados.
  Future<List<Guest>> getGuests() async {
    final db = await database;

    final rows = await db.query(
      'guests',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Guest.fromMap).toList();
  }

  // Buscar por nombre o folio.
  Future<List<Guest>> searchGuests(
    String query,
  ) async {
    final db = await database;
    final term = query.trim();

    if (term.isEmpty) return getGuests();

    final rows = await db.query(
      'guests',
      where: '''
        name LIKE ? COLLATE NOCASE
        OR code LIKE ? COLLATE NOCASE
      ''',
      whereArgs: ['%$term%', '%$term%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Guest.fromMap).toList();
  }

  // Obtener un pase por su folio exacto.
  Future<Guest?> getGuestByCode(
    String code,
  ) async {
    final db = await database;

    final rows = await db.query(
      'guests',
      where: 'code = ?',
      whereArgs: [code.trim().toUpperCase()],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return Guest.fromMap(rows.first);
  }

  // Confirmar entrada.
  // Solo actualiza si el pase no estaba usado.
  Future<bool> checkIn(String code) async {
    final db = await database;

    final updated = await db.update(
      'guests',
      {
        'used': 1,
        'checked_in_at':
            DateTime.now().toIso8601String(),
      },
      where: 'code = ? AND used = 0',
      whereArgs: [code.trim().toUpperCase()],
    );

    return updated == 1;
  }

  // Obtener estadísticas de asistencia.
  Future<Map<String, int>> getStatistics() async {
    final db = await database;

    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_passes,
        COALESCE(SUM(used), 0) AS used_passes,
        COALESCE(SUM(adults), 0) AS adults,
        COALESCE(SUM(children), 0) AS children,
        COALESCE(
          SUM(CASE WHEN used = 1 THEN adults ELSE 0 END),
          0
        ) AS checked_adults,
        COALESCE(
          SUM(CASE WHEN used = 1 THEN children ELSE 0 END),
          0
        ) AS checked_children
      FROM guests
    ''');

    return rows.first.map(
      (key, value) => MapEntry(key, value as int),
    );
  }
  
Future<ImportResult> importGuests(
  List<Guest> guests,
) async {
  final db = await database;

  return db.transaction((txn) async {
    int inserted = 0;
    int updated = 0;
    int unchanged = 0;

    for (final guest in guests) {
      final existingRows = await txn.query(
        'guests',
        where: 'code = ?',
        whereArgs: [guest.code],
        limit: 1,
      );

      if (existingRows.isEmpty) {
        await txn.insert(
          'guests',
          guest.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        inserted++;
        continue;
      }

      final existing = Guest.fromMap(
        existingRows.first,
      );

      final hasChanges =
          existing.name != guest.name ||
          existing.adults != guest.adults ||
          existing.children != guest.children;

      if (!hasChanges) {
        unchanged++;
        continue;
      }

      await txn.update(
        'guests',
        {
          'name': guest.name,
          'adults': guest.adults,
          'children': guest.children,
        },
        where: 'code = ?',
        whereArgs: [guest.code],
      );

      updated++;
    }

    return ImportResult(
      inserted: inserted,
      updated: updated,
      unchanged: unchanged,
    );
  });
}

}
