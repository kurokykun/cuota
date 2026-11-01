import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/features/profiles/data/secret_store.dart';
import 'package:cuota/features/profiles/domain/profile.dart';

Profile sampleProfile({
  String id = 'perfil',
  String localPort = '3128',
  String password = 'cl&ve<1>',
}) =>
    Profile(
      id: id,
      name: 'Perfil',
      color: ProfileColor.teal,
      username: 'usuario',
      password: password,
      localAddress: '127.0.0.1',
      localPort: localPort,
      upstreamHost: '10.0.0.1',
      upstreamPort: '8080',
      domain: 'uci.cu',
      noProxy: const ['localhost', '10.*'],
      gateway: false,
    );

class MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  bool available = true;

  void _check() {
    if (!available) throw const SecretStorageFailure('llavero no disponible');
  }

  @override
  Future<String?> read(String key) async {
    _check();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check();
    values.remove(key);
  }
}
