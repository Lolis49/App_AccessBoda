import 'dart:convert';

import 'package:excel/excel.dart';

/// Convierte la primera hoja con datos al formato de invitados existente.
class GuestExcelConverter {
  static String toJson(List<int> bytes) {
    if (bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('El archivo supera el límite de 5 MB.');
    }
    final Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const FormatException(
        'No se pudo leer el Excel. Usa un archivo .xlsx válido, sin contraseña.',
      );
    }

    for (final sheet in workbook.tables.values) {
      final rows = sheet.rows;
      final headerIndex = rows.indexWhere(
        (row) => row.any((cell) => !_empty(cell?.value)),
      );
      if (headerIndex < 0) continue;

      final columns = <String, int>{};
      final header = rows[headerIndex];
      for (var i = 0; i < header.length; i++) {
        final key = _header(header[i]?.value.toString() ?? '');
        if (key.isEmpty) continue;
        if (columns.containsKey(key)) {
          throw FormatException('La columna "$key" está duplicada.');
        }
        columns[key] = i;
      }
      for (final key in ['folio', 'nombre', 'adultos', 'ninos']) {
        if (!columns.containsKey(key)) {
          throw FormatException(
            'Falta la columna "$key" en la hoja "${sheet.sheetName}". '
            'Usa: Folio, Nombre, Adultos, Niños y Mesa.',
          );
        }
      }

      final guests = <String, dynamic>{};
      for (var i = headerIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((cell) => _empty(cell?.value))) continue;
        final rowNumber = i + 1;
        CellValue? value(String key) {
          final column = columns[key];
          return column == null || column >= row.length
              ? null
              : row[column]?.value;
        }

        final code = _text(value('folio'), 'Folio', rowNumber).toUpperCase();
        if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(code)) {
          throw FormatException(
            'Fila $rowNumber: el folio debe tener 8 letras o números.',
          );
        }
        if (guests.containsKey(code)) {
          throw FormatException(
              'Fila $rowNumber: el folio $code está duplicado.');
        }
        final adults = _integer(value('adultos'), 'Adultos', rowNumber);
        final children = _integer(value('ninos'), 'Niños', rowNumber);
        if (adults + children == 0) {
          throw FormatException(
              'Fila $rowNumber: debe incluir al menos una persona.');
        }
        final mesa = value('mesa');
        guests[code] = {
          'name': _text(value('nombre'), 'Nombre', rowNumber),
          'adults': adults,
          'children': children,
          if (!_empty(mesa))
            'mesa': _integer(mesa, 'Mesa', rowNumber, minimum: 1),
        };
      }
      if (guests.isEmpty) {
        throw const FormatException('La hoja no contiene invitados.');
      }
      return jsonEncode(guests);
    }
    throw const FormatException('El archivo Excel está vacío.');
  }

  static bool _empty(CellValue? value) =>
      value == null || value.toString().trim().isEmpty;

  static String _header(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('é', 'e');
    return const {
          'code': 'folio',
          'name': 'nombre',
          'adults': 'adultos',
          'children': 'ninos',
          'numero de mesa': 'mesa',
          'table_number': 'mesa',
        }[normalized] ??
        normalized;
  }

  static String _text(CellValue? value, String label, int row) {
    final String result;
    if (value is TextCellValue || value is IntCellValue) {
      result = value.toString().trim();
    } else {
      throw FormatException(
          'Fila $row: "$label" debe contener texto o un entero.');
    }
    if (result.isEmpty) {
      throw FormatException('Fila $row: falta "$label".');
    }
    return result;
  }

  static int _integer(CellValue? value, String label, int row,
      {int minimum = 0}) {
    final num? number;
    if (value is IntCellValue) {
      number = value.value;
    } else if (value is DoubleCellValue) {
      number = value.value;
    } else if (value is TextCellValue) {
      number = num.tryParse(value.toString().trim());
    } else {
      number = null;
    }
    if (number == null ||
        !number.isFinite ||
        number < minimum ||
        number != number.truncateToDouble()) {
      throw FormatException(
        'Fila $row: "$label" debe ser un entero mayor o igual a $minimum.',
      );
    }
    return number.toInt();
  }
}
