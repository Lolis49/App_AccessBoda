import 'dart:io';

import 'package:excel/excel.dart';

void main() {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow(['Folio', 'Nombre', 'Adultos', 'Niños', 'Mesa']
      .map(TextCellValue.new)
      .toList());
  sheet.appendRow([
    TextCellValue('TEST2027'),
    TextCellValue('Familia de ejemplo'),
    IntCellValue(2),
    IntCellValue(1),
    IntCellValue(8),
  ]);
  final file = File('templates/invitados_boda.xlsx');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(excel.encode()!);
}
