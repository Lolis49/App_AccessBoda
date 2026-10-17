import 'package:flutter_test/flutter_test.dart';
import 'package:lolis_jose_access/models/attendance_statistics.dart';
import 'package:lolis_jose_access/models/guest.dart';

void main() {
  test('Sin invitados todos los contadores y el porcentaje son cero', () {
    final stats = AttendanceStatistics.fromGuests([]);
    expect(stats.totalPasses, 0);
    expect(stats.invited, 0);
    expect(stats.checkedIn, 0);
    expect(stats.pending, 0);
    expect(stats.progress, 0);
    expect(stats.tables, isEmpty);
  });

  test('Distingue personas y pases y agrupa mesas en orden numerico', () {
    final stats = AttendanceStatistics.fromGuests(const [
      Guest(
          code: 'TEST0001',
          name: 'Completo',
          adults: 2,
          children: 1,
          checkedInAdults: 2,
          checkedInChildren: 1,
          tableNumber: 10),
      Guest(
          code: 'TEST0002',
          name: 'Parcial',
          adults: 2,
          children: 2,
          checkedInAdults: 1,
          tableNumber: 2),
      Guest(
          code: 'TEST0003',
          name: 'Pendiente',
          adults: 1,
          children: 0,
          tableNumber: 2),
      Guest(code: 'TEST0004', name: 'Sin mesa', adults: 1, children: 0),
    ]);
    expect(stats.totalPasses, 4);
    expect(stats.completePasses, 1);
    expect(stats.partialPasses, 1);
    expect(stats.pendingPasses, 2);
    expect(stats.invited, 9);
    expect(stats.checkedIn, 4);
    expect(stats.pending, 5);
    expect(stats.pendingAdults, 3);
    expect(stats.pendingChildren, 2);
    expect(stats.progress, closeTo(4 / 9, 0.00001));
    expect(stats.tables.map((table) => table.tableNumber), [2, 10, null]);
    expect(stats.tables.first.invited, 5);
    expect(stats.tables.first.checkedIn, 1);
    expect(stats.tables.first.pending, 4);
    expect(stats.tables.last.label, 'Sin mesa asignada');
    expect(stats.tables.fold<int>(0, (sum, table) => sum + table.invited),
        stats.invited);
    expect(stats.tables.fold<int>(0, (sum, table) => sum + table.checkedIn),
        stats.checkedIn);
  });
}
