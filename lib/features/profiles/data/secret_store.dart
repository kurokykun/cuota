import 'package:cuota/core/errors/failures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// [SecretStore] backed by the system keyring.
class KeyringSecretStore implements SecretStore {
  const KeyringSecretStore([this._storage = const FlutterSecureStorage()]);

  static const _failure = SecretStorageFailure(
      'No se pudo acceder al llavero del sistema, la contraseña no se guardó');

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => _guard(() => _storage.delete(key: key));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      throw _failure;
    } on MissingPluginException {
      throw _failure;
    }
  }
}
