import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lolis_jose_access/models/attendance_statistics.dart';
import 'package:lolis_jose_access/models/guest.dart';
import 'package:lolis_jose_access/screens/statistics_screen.dart';
import 'package:lolis_jose_access/theme/app_theme.dart';

void main() {
  testWidgets('Muestra asistencia y se actualiza desde el boton',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: StatisticsScreen(loadStatistics: () async {
        loads++;
        return AttendanceStatistics.fromGuests([
          Guest(
              code: 'TEST2027',
              name: 'Familia',
              adults: 2,
              children: 0,
              checkedInAdults: loads == 1 ? 1 : 2,
              tableNumber: 8),
        ]);
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('50.0 %'), findsOneWidget);
    expect(find.text('Estado de las invitaciones'), findsOneWidget);
    await tester.tap(find.byTooltip('Actualizar estadísticas'));
    await tester.pumpAndSettle();
    expect(find.text('100.0 %'), findsOneWidget);
    expect(loads, 2);
  });

  testWidgets('Sin invitados muestra ceros y permite desplazar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: StatisticsScreen(
      loadStatistics: () async => AttendanceStatistics.fromGuests([]),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay invitados'), findsOneWidget);
    expect(find.text('0.0 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Permite reintentar despues de un error de lectura',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(home: StatisticsScreen(
      loadStatistics: () async {
        if (++attempts == 1) throw StateError('Error de lectura');
        return AttendanceStatistics.fromGuests([]);
      },
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudieron cargar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('0.0 %'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('El panel se puede recorrer en un telefono estrecho',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: StatisticsScreen(
          loadStatistics: () async => AttendanceStatistics.fromGuests(const [
                Guest(
                    code: 'TEST2027',
                    name: 'Familia',
                    adults: 2,
                    children: 1,
                    checkedInAdults: 1,
                    tableNumber: 8),
              ])),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mesa 8'), 250);
    expect(find.text('Mesa 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
