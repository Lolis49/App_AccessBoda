import 'package:flutter_test/flutter_test.dart';
import 'package:lolis_jose_access/models/guest.dart';

void main() {
  final json = <String, dynamic>{
    'name': 'Familia de prueba',
    'adults': 2,
    'children': 1,
  };

  test('La mesa del JSON se conserva al guardar y recuperar el pase', () {
    final guest = Guest.fromJson('TEST2027', {...json, 'mesa': 8});
    final restored = Guest.fromMap(guest.toMap());
    expect(restored.tableNumber, 8);
    expect(restored.tableLabel, '8');
    expect(restored.adults, 2);
    expect(restored.children, 1);
  });

  test('Los JSON y registros anteriores admiten no tener mesa', () {
    final guest = Guest.fromJson('TEST2027', json);
    final legacyMap = guest.toMap()..remove('table_number');
    expect(Guest.fromMap(legacyMap).tableNumber, isNull);
    expect(guest.tableLabel, 'Sin asignar');
  });

  test('Rechaza mesas con formato o numero invalido', () {
    for (final value in [0, -1, 1.5, '8', true, <int>[]]) {
      expect(
        () => Guest.fromJson('TEST2027', {...json, 'mesa': value}),
        throwsFormatException,
      );
    }
  });
}
