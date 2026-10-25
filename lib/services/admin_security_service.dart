import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AdminAction { importGuests, resetCheckIns, changePin }

class AdminPinException implements Exception {
  final String message;
  const AdminPinException(this.message);
  @override
  String toString() => message;
}

/// Permiso de una sola operacion, emitido al verificar el PIN.
class AdminAuthorization {
  final AdminSecurityService _owner;
  final Object _generation;
  final AdminAction _action;
  final DateTime _expiresAt;
  bool _consumed = false;

  AdminAuthorization._(
      this._owner, this._generation, this._action, this._expiresAt);
}

abstract class AdminPinStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureAdminPinStore implements AdminPinStore {
  static const _key = 'lj_admin_security_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

class AdminSecurityService {
  static final instance = AdminSecurityService(store: SecureAdminPinStore());
  final AdminPinStore _store;
  final DateTime Function() _now;
  Object _generation = Object();
  bool _busy = false;
  static final _pinPattern = RegExp(r'^[0-9]{6}$');
  static final _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  AdminSecurityService({required AdminPinStore store, DateTime Function()? now})
      : _store = store,
        _now = now ?? DateTime.now;

  Future<Map<String, dynamic>?> _read() async {
    final raw = await _store.read();
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data['version'] != 1 ||
        data['salt'] is! String ||
        data['hash'] is! String ||
        data['failures'] is! int ||
        (data['failures'] as int) < 0 ||
        data['lockedUntil'] is! int ||
        base64Decode(data['salt'] as String).length != 32 ||
        base64Decode(data['hash'] as String).length != 32) {
      throw const AdminPinException(
          'No se pudo leer la configuración de seguridad.');
    }
    return data;
  }

  Future<bool> isConfigured() async => await _read() != null;

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_busy) {
      throw const AdminPinException('Espera a que termine la verificación.');
    }
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }

  void _validatePin(String pin) {
    if (!_pinPattern.hasMatch(pin)) {
      throw const AdminPinException('El PIN debe tener exactamente 6 dígitos.');
    }
  }

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<void> _savePin(String pin) async {
    _validatePin(pin);
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final hash = await _derive(pin, salt);
    await _store.write(jsonEncode({
      'version': 1,
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
      'failures': 0,
      'lockedUntil': 0,
    }));
    _generation = Object();
  }

  AdminAuthorization _issue(AdminAction action) => AdminAuthorization._(
        this,
        _generation,
        action,
        _now().add(const Duration(minutes: 5)),
      );

  Future<AdminAuthorization> configure(String pin, AdminAction action) {
    return _exclusive(() async {
      if (await _read() != null) {
        throw const AdminPinException('El PIN ya existe. Usa Cambiar PIN.');
      }
      await _savePin(pin);
      return _issue(action);
    });
  }

  Future<AdminAuthorization> authorize(String pin, AdminAction action) {
    return _exclusive(() async {
      final data = await _read();
      if (data == null) {
        throw const AdminPinException('Configura primero el PIN.');
      }
      final lockedUntil = data['lockedUntil'] as int;
      final remaining = lockedUntil - _now().millisecondsSinceEpoch;
      if (remaining > 0) {
        throw AdminPinException(
            'Demasiados intentos. Espera ${(remaining / 1000).ceil()} segundos.');
      }
      _validatePin(pin);
      final actual = await _derive(pin, base64Decode(data['salt'] as String));
      final expected = base64Decode(data['hash'] as String);
      var difference = 0;
      for (var i = 0; i < expected.length; i++) {
        difference |= actual[i] ^ expected[i];
      }
      if (difference != 0) {
        final failures = (lockedUntil > 0 ? 0 : data['failures'] as int) + 1;
        final locked = failures >= 5;
        data['failures'] = locked ? 0 : failures;
        data['lockedUntil'] = locked
            ? _now().add(const Duration(seconds: 30)).millisecondsSinceEpoch
            : 0;
        await _store.write(jsonEncode(data));
        throw AdminPinException(locked
            ? 'Demasiados intentos. Espera 30 segundos.'
            : 'PIN incorrecto. Quedan ${5 - failures} intentos.');
      }
      data['failures'] = 0;
      data['lockedUntil'] = 0;
      await _store.write(jsonEncode(data));
      return _issue(action);
    });
  }

  void requireAuthorization(
      AdminAuthorization authorization, AdminAction action,
      {bool consume = false}) {
    if (!identical(authorization._owner, this) ||
        !identical(authorization._generation, _generation) ||
        authorization._action != action ||
        authorization._consumed ||
        !_now().isBefore(authorization._expiresAt)) {
      throw const AdminPinException(
          'La autorización venció. Ingresa de nuevo el PIN.');
    }
    if (consume) authorization._consumed = true;
  }

  Future<void> changePin(AdminAuthorization authorization, String newPin) {
    return _exclusive(() async {
      _validatePin(newPin);
      requireAuthorization(authorization, AdminAction.changePin, consume: true);
      await _savePin(newPin);
    });
  }
}
