
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/guest.dart';
import 'database_service.dart';

import '../models/import_result.dart';

class GuestImportService {
  static final RegExp _codePattern =
      RegExp(r'^[A-Z0-9]{8}$');

  Future<ImportResult?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      allowMultiple: false,
    );

    if (result == null) {
      return null;
    }

    final PlatformFile file = result.files.single;

    final Uint8List? bytes = file.bytes;

    if (bytes == null) {
      throw const FormatException(
        'No se pudo leer el archivo seleccionado.',
      );
    }

    // Limitar el tamaño del archivo a 5 MB.
    if (bytes.length > 5 * 1024 * 1024) {
      throw const FormatException(
        'El archivo supera el límite de 5 MB.',
      );
    }

    final String content;

    try {
      content = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException(
        'El archivo debe estar codificado en UTF-8.',
      );
    }

    return importFromJson(content);
  }

  Future<ImportResult> importFromJson(
    String content,
  ) async {
    dynamic decoded;

    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw const FormatException(
        'El archivo no contiene un JSON válido.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'El JSON debe contener un objeto de folios.',
      );
    }

    if (decoded.isEmpty) {
      throw const FormatException(
        'El archivo no contiene invitados.',
      );
    }

    final guests = <Guest>[];
    final normalizedCodes = <String>{};

    for (final entry in decoded.entries) {
      final code = entry.key.trim().toUpperCase();

      if (!_codePattern.hasMatch(code)) {
        throw FormatException(
          'El folio "${entry.key}" no es válido. '
          'Debe tener 8 letras o números.',
        );
      }

      if (!normalizedCodes.add(code)) {
        throw FormatException(
          'El folio $code está duplicado.',
        );
      }

      final value = entry.value;

      if (value is! Map<String, dynamic>) {
        throw FormatException(
          'Los datos del folio $code no son válidos.',
        );
      }

      final name = value['name'];
      final adults = value['adults'];
      final children = value['children'];

      if (name is! String || name.trim().isEmpty) {
        throw FormatException(
          'El folio $code no tiene un nombre válido.',
        );
      }

      if (adults is! int || adults < 0) {
        throw FormatException(
          'El número de adultos de $code no es válido.',
        );
      }

      if (children is! int || children < 0) {
        throw FormatException(
          'El número de niños de $code no es válido.',
        );
      }

      if (adults + children == 0) {
        throw FormatException(
          'El folio $code debe incluir al menos '
          'una persona.',
        );
      }

      guests.add(
        Guest(
          code: code,
          name: name.trim(),
          adults: adults,
          children: children,
        ),
      );
    }

    // La validación completa ocurre antes
    // de modificar la base de datos.
    return DatabaseService.instance.importGuests(
      guests,
    );
  }
}
