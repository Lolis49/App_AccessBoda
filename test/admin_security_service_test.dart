import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lolis_jose_access/services/admin_security_service.dart';
import 'package:lolis_jose_access/services/database_service.dart';
import 'package:lolis_jose_access/services/guest_import_service.dart';

class MemoryPinStore implements AdminPinStore {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    if (failWrites) throw StateError('Almacenamiento no disponible');
    value = data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final denied = isA<AdminPinException>();

  test('Requiere configurar PIN, rechaza formatos y no permite sobrescribirlo',
      () async {
    final store = MemoryPinStore();
    final security = AdminSecurityService(store: store);
    expect(await security.isConfigured(), isFalse);
    await expectLater(security.authorize('123456', AdminAction.importGuests),
        throwsA(denied));
    for (final pin in ['1234', '1234567', 'abcdef']) {
      await expectLater(
          security.configure(pin, AdminAction.importGuests), throwsA(denied));
    }
    await security.configure('123456', AdminAction.importGuests);
    expect(await security.isConfigured(), isTrue);
    expect(store.value, isNot(contains('123456')));
    await expectLater(security.configure('654321', AdminAction.importGuests),
        throwsA(denied));
  });

  test('Los permisos corresponden a una accion, vencen y no se reutilizan',
      () async {
    var now = DateTime.utc(2026, 10, 17);
    final security =
        AdminSecurityService(store: MemoryPinStore(), now: () => now);
    final grant = await security.configure('123456', AdminAction.importGuests);
    expect(
        () => security.requireAuthorization(grant, AdminAction.resetCheckIns),
        throwsA(denied));
    security.requireAuthorization(grant, AdminAction.importGuests,
        consume: true);
    expect(() => security.requireAuthorization(grant, AdminAction.importGuests),
        throwsA(denied));
    final expiring =
        await security.authorize('123456', AdminAction.importGuests);
    now = now.add(const Duration(minutes: 5));
    expect(
        () => security.requireAuthorization(expiring, AdminAction.importGuests),
        throwsA(denied));
  });

  test(
      'Cinco errores bloquean incluso en otra instancia y luego permiten verificar',
      () async {
    var now = DateTime.utc(2026, 10, 17);
    final store = MemoryPinStore();
    final security = AdminSecurityService(store: store, now: () => now);
    await security.configure('123456', AdminAction.importGuests);
    for (var i = 0; i < 5; i++) {
      await expectLater(security.authorize('999999', AdminAction.importGuests),
          throwsA(denied));
    }
    final reopened = AdminSecurityService(store: store, now: () => now);
    await expectLater(
        reopened.authorize('123456', AdminAction.importGuests),
        throwsA(isA<AdminPinException>().having(
            (error) => error.message, 'bloqueo', contains('30 segundos'))));
    now = now.add(const Duration(seconds: 31));
    final grant = await reopened.authorize('123456', AdminAction.importGuests);
    reopened.requireAuthorization(grant, AdminAction.importGuests);
    expect(jsonDecode(store.value!)['failures'], 0);
  });

  test('Cambiar PIN invalida el anterior y los permisos emitidos previamente',
      () async {
    final security = AdminSecurityService(store: MemoryPinStore());
    final previous =
        await security.configure('123456', AdminAction.importGuests);
    final change = await security.authorize('123456', AdminAction.changePin);
    await security.changePin(change, '654321');
    expect(
        () => security.requireAuthorization(previous, AdminAction.importGuests),
        throwsA(denied));
    await expectLater(security.authorize('123456', AdminAction.importGuests),
        throwsA(denied));
    final grant = await security.authorize('654321', AdminAction.importGuests);
    security.requireAuthorization(grant, AdminAction.importGuests);
  });

  test('Almacenamiento corrupto o fallido no emite permisos ni reconfigura PIN',
      () async {
    final store = MemoryPinStore()..value = '{}';
    final security = AdminSecurityService(store: store);
    await expectLater(security.isConfigured(), throwsA(denied));
    await expectLater(security.configure('123456', AdminAction.importGuests),
        throwsA(denied));
    store.value = null;
    store.failWrites = true;
    await expectLater(security.configure('123456', AdminAction.importGuests),
        throwsStateError);
    expect(store.value, isNull);
  });

  test(
      'Importacion y reinicio rechazan permisos ajenos o de otra accion antes de acceder a datos',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final security = AdminSecurityService.instance;
    final importGrant =
        await security.configure('123456', AdminAction.importGuests);
    await expectLater(
        DatabaseService.instance.resetAllCheckIns(authorization: importGrant),
        throwsA(denied));
    final foreign = await AdminSecurityService(store: MemoryPinStore())
        .configure('123456', AdminAction.importGuests);
    await expectLater(
        DatabaseService.instance.importGuests([], authorization: foreign),
        throwsA(denied));
    await expectLater(
        GuestImportService().importFromJson('{}', authorization: foreign),
        throwsA(denied));
    security.requireAuthorization(importGrant, AdminAction.importGuests,
        consume: true);
    await expectLater(
        DatabaseService.instance.importGuests([], authorization: importGrant),
        throwsA(denied));
  });
}
