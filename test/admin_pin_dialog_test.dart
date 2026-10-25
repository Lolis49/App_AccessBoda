import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lolis_jose_access/services/admin_security_service.dart';
import 'package:lolis_jose_access/widgets/admin_pin_dialog.dart';

import 'admin_security_service_test.dart' show MemoryPinStore;

void main() {
  testWidgets(
      'Crear y verificar el PIN cierra el dialogo y concede solo la accion pedida',
      (tester) async {
    final security = AdminSecurityService(store: MemoryPinStore());
    AdminAuthorization? grant;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
      builder: (context) => Scaffold(
          body: TextButton(
        onPressed: () async {
          grant = await requestAdminAuthorization(context,
              action: AdminAction.importGuests,
              reason: 'Importar Excel',
              security: security);
        },
        child: const Text('Abrir'),
      )),
    )));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.text('Guardar PIN'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminPinDialog), findsNothing);
    expect(grant, isNotNull);
    security.requireAuthorization(grant!, AdminAction.importGuests,
        consume: true);
    grant = null;
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Autorizar'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminPinDialog), findsNothing);
    expect(grant, isNotNull);
    security.requireAuthorization(grant!, AdminAction.importGuests);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Crear PIN exige confirmacion y cancelar no concede acceso',
      (tester) async {
    final security = AdminSecurityService(store: MemoryPinStore());
    var granted = false;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        final authorization = await requestAdminAuthorization(
                            context,
                            action: AdminAction.importGuests,
                            reason: 'Importar Excel',
                            security: security);
                        granted = authorization != null;
                      },
                      child: const Text('Importar')),
                ))));
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.text('Crear PIN de administrador'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.enterText(find.byType(TextField).at(1), '654321');
    await tester.tap(find.text('Guardar PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Los PIN no coinciden.'), findsOneWidget);
    expect(await security.isConfigured(), isFalse);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(granted, isFalse);
  });

  testWidgets('PIN existente pide un unico campo oculto y permite cancelar',
      (tester) async {
    final security = AdminSecurityService(store: MemoryPinStore());
    await tester
        .runAsync(() => security.configure('123456', AdminAction.importGuests));
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => requestAdminAuthorization(context,
                          action: AdminAction.resetCheckIns,
                          reason: 'Reiniciar',
                          security: security),
                      child: const Text('Abrir')),
                ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminPinDialog), findsNothing);
  });
}
