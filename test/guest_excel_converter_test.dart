import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lolis_jose_access/services/guest_excel_converter.dart';

List<int> workbook(List<List<CellValue?>> rows) {
  final excel = Excel.createExcel();
  for (final row in rows) {
    excel['Sheet1'].appendRow(row);
  }
  return excel.encode()!;
}

List<CellValue> get headers => ['Folio', 'Nombre', 'Adultos', 'Niños', 'Mesa']
    .map(TextCellValue.new)
    .toList();

List<CellValue?> guest(
        {String code = 'TEST2027',
        CellValue? adults,
        CellValue? children,
        CellValue? mesa}) =>
    [
      TextCellValue(code),
      TextCellValue('Familia Pérez'),
      adults ?? IntCellValue(2),
      children ?? IntCellValue(1),
      mesa,
    ];

void main() {
  test('Convierte Excel real a JSON con mesa y nombre con acentos', () {
    final result = jsonDecode(GuestExcelConverter.toJson(workbook([
      headers,
      guest(mesa: IntCellValue(8)),
    ])));
    expect(result['TEST2027'], {
      'name': 'Familia Pérez',
      'adults': 2,
      'children': 1,
      'mesa': 8,
    });
  });

  test('Admite columnas reordenadas, filas vacias y mesa sin asignar', () {
    final result = jsonDecode(GuestExcelConverter.toJson(workbook([
      [
        TextCellValue('Nombre'),
        TextCellValue('Niños'),
        TextCellValue('Folio'),
        TextCellValue('Adultos')
      ],
      [],
      [
        TextCellValue('Familia'),
        IntCellValue(0),
        TextCellValue('00001234'),
        TextCellValue('2')
      ],
    ])));
    expect(result['00001234']['adults'], 2);
    expect(result['00001234'].containsKey('mesa'), isFalse);
  });

  test('Rechaza folios duplicados antes de construir el JSON', () {
    expect(
        () => GuestExcelConverter.toJson(workbook([
              headers,
              guest(),
              guest(code: 'test2027'),
            ])),
        throwsFormatException);
  });

  test('Rechaza cantidades negativas, fracciones y mesas invalidas', () {
    for (final row in [
      guest(adults: IntCellValue(-1)),
      guest(children: DoubleCellValue(1.5)),
      guest(mesa: IntCellValue(0)),
      guest(adults: FormulaCellValue('1+1')),
      guest(adults: IntCellValue(0), children: IntCellValue(0)),
      guest(code: 'INVALID'),
    ]) {
      expect(() => GuestExcelConverter.toJson(workbook([headers, row])),
          throwsFormatException);
    }
  });

  test('Rechaza encabezados ausentes, hoja sin invitados y archivo corrupto',
      () {
    for (final bytes in [
      workbook([
        [TextCellValue('Nombre')],
        [TextCellValue('Familia')]
      ]),
      workbook([headers]),
      <int>[1, 2, 3],
    ]) {
      expect(() => GuestExcelConverter.toJson(bytes), throwsFormatException);
    }
  });
}
