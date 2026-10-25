import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/guest.dart';
import 'admin_security_service.dart';
import '../models/attendance_statistics.dart';
import '../models/import_result.dart';
import '../models/check_in_event.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE guests (
          code TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          adults INTEGER NOT NULL,
          children INTEGER NOT NULL,
          table_number INTEGER,
          used INTEGER NOT NULL DEFAULT 0,
          checked_in_at TEXT,
          checked_in_adults INTEGER NOT NULL DEFAULT 0,
          checked_in_children INTEGER NOT NULL DEFAULT 0
        )
      ''');

        await db.execute('''
        CREATE INDEX idx_guests_name
        ON guests(name)
      ''');

        await _createCheckInTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
          ALTER TABLE guests
          ADD COLUMN checked_in_adults
          INTEGER NOT NULL DEFAULT 0
        ''');

          await db.execute('''
          ALTER TABLE guests
          ADD COLUMN checked_in_children
          INTEGER NOT NULL DEFAULT 0
        ''');

          // Los pases anteriormente marcados como
          // utilizados se consideran completos.
          await db.execute('''
          UPDATE guests
          SET
            checked_in_adults = adults,
            checked_in_children = children
          WHERE used = 1
        ''');

          await _createCheckInTable(db);
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE guests ADD COLUMN table_number INTEGER',
          );
        }
      },
    );
  }

  Future<void> _createCheckInTable(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
    CREATE TABLE check_in_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      guest_code TEXT NOT NULL,
      adults INTEGER NOT NULL,
      children INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (guest_code)
        REFERENCES guests(code)
    )
  ''');

    await db.execute('''
    CREATE INDEX idx_check_in_events_guest
    ON check_in_events(guest_code)
  ''');
  }

  // Importar invitados iniciales desde JSON.
  // Solo se ejecuta cuando la tabla está vacía.
  Future<void> seedGuests() async {
    final db = await database;

    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM guests',
          ),
        ) ??
        0;

    if (count > 0) return;

    final jsonString = await rootBundle.loadString(
      'assets/data/guests.json',
    );

    final data = jsonDecode(jsonString) as Map<String, dynamic>;

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
    final guest = await getGuestByCode(code);

    if (guest == null || guest.totalPending == 0) {
      return false;
    }

    try {
      await registerPartialEntry(
        code: guest.code,
        adults: guest.pendingAdults,
        children: guest.pendingChildren,
      );

      return true;
    } on StateError {
      return false;
    }
  }

  // Obtener estadísticas de asistencia.

  Future<AttendanceStatistics> getAttendanceStatistics() async {
    return AttendanceStatistics.fromGuests(await getGuests());
  }

  Future<Map<String, int>> getStatistics() async {
    final db = await database;

    final rows = await db.rawQuery('''
    SELECT
      COUNT(*) AS total_passes,

      COALESCE(SUM(
        CASE WHEN used = 1 THEN 1 ELSE 0 END
      ), 0) AS used_passes,

      COALESCE(SUM(adults), 0) AS adults,
      COALESCE(SUM(children), 0) AS children,

      COALESCE(SUM(checked_in_adults), 0)
        AS checked_adults,

      COALESCE(SUM(checked_in_children), 0)
        AS checked_children,

      COALESCE(SUM(
        CASE
          WHEN checked_in_adults +
               checked_in_children > 0
           AND used = 0
          THEN 1 ELSE 0
        END
      ), 0) AS partial_passes

    FROM guests
  ''');

    return rows.first.map(
      (key, value) => MapEntry(key, value as int),
    );
  }

  Future<ImportResult> importGuests(
    List<Guest> guests, {
    required AdminAuthorization authorization,
  }) async {
    AdminSecurityService.instance.requireAuthorization(
      authorization,
      AdminAction.importGuests,
      consume: true,
    );
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

        if (guest.adults < existing.checkedInAdults ||
            guest.children < existing.checkedInChildren) {
          throw StateError(
            'No se puede actualizar el folio '
            '${guest.code}: las nuevas cantidades '
            'son menores que las personas '
            'que ya ingresaron.',
          );
        }

        // Los archivos anteriores sin mesa conservan la asignacion existente.
        final tableNumber = guest.tableNumber ?? existing.tableNumber;
        final hasChanges = existing.name != guest.name ||
            existing.tableNumber != tableNumber ||
            existing.adults != guest.adults ||
            existing.children != guest.children;

        if (!hasChanges) {
          unchanged++;
          continue;
        }

        final isComplete = existing.checkedInAdults == guest.adults &&
            existing.checkedInChildren == guest.children;

        await txn.update(
          'guests',
          {
            'name': guest.name,
            'adults': guest.adults,
            'children': guest.children,
            'table_number': tableNumber,
            'used': isComplete ? 1 : 0,
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

  Future<void> registerPartialEntry({
    required String code,
    required int adults,
    required int children,
  }) async {
    if (adults < 0 || children < 0) {
      throw ArgumentError(
        'Las cantidades no pueden ser negativas.',
      );
    }

    if (adults + children == 0) {
      throw ArgumentError(
        'Debes registrar al menos una persona.',
      );
    }

    final db = await database;
    final normalizedCode = code.trim().toUpperCase();

    await db.transaction((txn) async {
      final rows = await txn.query(
        'guests',
        where: 'code = ?',
        whereArgs: [normalizedCode],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('El pase no existe.');
      }

      final guest = Guest.fromMap(rows.first);

      if (adults > guest.pendingAdults || children > guest.pendingChildren) {
        throw StateError(
          'La cantidad supera los lugares disponibles.',
        );
      }

      final newAdults = guest.checkedInAdults + adults;

      final newChildren = guest.checkedInChildren + children;

      final isComplete =
          newAdults == guest.adults && newChildren == guest.children;

      final now = DateTime.now().toIso8601String();

      await txn.update(
        'guests',
        {
          'checked_in_adults': newAdults,
          'checked_in_children': newChildren,
          'used': isComplete ? 1 : 0,
          'checked_in_at': guest.checkedInAt?.toIso8601String() ?? now,
        },
        where: 'code = ?',
        whereArgs: [normalizedCode],
      );

      await txn.insert(
        'check_in_events',
        {
          'guest_code': normalizedCode,
          'adults': adults,
          'children': children,
          'created_at': now,
        },
      );
    });
  }

  Future<List<CheckInEvent>> getCheckInHistory(
    String code,
  ) async {
    final db = await database;

    final rows = await db.query(
      'check_in_events',
      where: 'guest_code = ?',
      whereArgs: [code.trim().toUpperCase()],
      orderBy: 'created_at DESC, id DESC',
    );

    return rows.map(CheckInEvent.fromMap).toList();
  }

  Future<void> resetAllCheckIns(
      {required AdminAuthorization authorization}) async {
    AdminSecurityService.instance.requireAuthorization(
      authorization,
      AdminAction.resetCheckIns,
      consume: true,
    );
    final db = await database;

    await db.transaction((txn) async {
      // Eliminar el historial de entradas.
      await txn.delete('check_in_events');

      // Reiniciar todos los pases.
      await txn.update(
        'guests',
        {
          'checked_in_adults': 0,
          'checked_in_children': 0,
          'used': 0,
          'checked_in_at': null,
        },
      );
    });
  }
}
