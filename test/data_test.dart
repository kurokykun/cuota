import 'dart:convert';
import 'dart:io';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/network/secure_http_client.dart';
import 'package:cuota/features/account/data/http_account_repository.dart';
import 'package:cuota/features/account/domain/account.dart';
import 'package:cuota/features/profiles/data/file_profile_repository.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/proxy/data/cntlm_config.dart';
import 'package:cuota/features/quota/data/soap_quota_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

String quotaResponse(String total, String used) => '''
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <resultado><cuota>$total</cuota><cuota_usada>$used</cuota_usada></resultado>
  </soap:Body>
</soap:Envelope>
''';

void main() {
  late Directory dir;
  late MemorySecretStore secrets;
  late FileProfileRepository repository;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cuota_test');
    secrets = MemorySecretStore();
    repository = FileProfileRepository(directory: dir.path, secrets: secrets);
  });

  tearDown(() => dir.delete(recursive: true));

  group('FileProfileRepository', () {
    const legacy = '{"name":"Viejo","color":"blue","usser":"u","pass":"secreto",'
        '"local_port":"3128","local_proxy":"127.0.0.1",'
        '"upstream_proxy":"10.0.0.1","upstream_proxy_port":"8080",'
        '"domain":"uci.cu","no_proxy":["localhost"],"gateway":false}';

    test('moves a legacy password from the file to the keyring', () async {
      final file = File('${dir.path}/viejo.conf')..writeAsStringSync(legacy);

      final catalog = await repository.loadAll();

      expect(catalog.profiles.single.password, 'secreto');
      expect(secrets.values['cuota.profile.viejo'], 'secreto');
      expect(file.readAsStringSync(), isNot(contains('secreto')));
      expect((await repository.loadAll()).profiles.single.password, 'secreto');
    });

    test('keeps the legacy password in place if the keyring fails', () async {
      final file = File('${dir.path}/viejo.conf')..writeAsStringSync(legacy);
      secrets.available = false;

      final catalog = await repository.loadAll();

      expect(catalog.secretsAvailable, isFalse);
      expect(catalog.profiles.single.password, 'secreto');
      expect(file.readAsStringSync(), contains('secreto'));
      await expectLater(repository.save(catalog.profiles.single),
          throwsA(isA<SecretStorageFailure>()));
      expect(file.readAsStringSync(), contains('secreto'));
    });

    test('skips corrupt and foreign files, keeping the valid ones', () async {
      File('${dir.path}/malo.conf').writeAsStringSync('{"name": "a"');
      File('${dir.path}/ca.pem').writeAsStringSync('no es un perfil');
      await repository.create('Bueno');

      final catalog = await repository.loadAll();

      expect(catalog.profiles.map((p) => p.name), ['Bueno']);
      expect(catalog.corruptFiles, ['malo.conf']);
    });

    test('accepts any character in names', () async {
      final created = await repository.create('Casa "1"/../x');

      expect(created.id, 'casa-1-x');
      final loaded = (await repository.loadAll()).profiles.single;
      expect(loaded.name, 'Casa "1"/../x');
    });

    test('persists every field but keeps the password out of the file',
        () async {
      final created = await repository.create('Perfil');
      await repository.save(created.copyWith(
        password: 'clave',
        noProxy: ['uno', 'dos'],
        color: ProfileColor.purple,
      ));

      final loaded = (await repository.loadAll()).profiles.single;
      expect(loaded.noProxy, ['uno', 'dos']);
      expect(loaded.password, 'clave');
      expect(loaded.color, ProfileColor.purple);
      final contents = File('${dir.path}/perfil.conf').readAsStringSync();
      expect(contents, isNot(contains('clave')));
    });

    test('profile files are private', () async {
      await repository.create('Perfil');

      final mode = File('${dir.path}/perfil.conf').statSync().modeString();
      expect(mode, 'rw-------');
    }, skip: Platform.isWindows);

    test('deleting removes the file and the password', () async {
      final created = await repository.create('Perfil');
      await repository.save(created.copyWith(password: 'clave'));

      await repository.delete(created.id);

      expect((await repository.loadAll()).profiles, isEmpty);
      expect(secrets.values, isEmpty);
    });
  });

  group('SoapQuotaRepository', () {
    test('escapes the credentials', () {
      final request = SoapQuotaRepository.buildRequest(sampleProfile());

      final document = XmlDocument.parse(request);
      expect(document.findAllElements('clave').single.innerText, 'cl&ve<1>');
    });

    test('accepts decimals in both values', () {
      final quota =
          SoapQuotaRepository.parseResponse(quotaResponse('400.00', '100.75'));

      expect(quota.total, 400);
      expect(quota.used, 100.75);
    });

    test('rejects invalid or incomplete responses', () {
      for (final body in ['no es xml', '<a/>', quotaResponse('x', '1')]) {
        expect(() => SoapQuotaRepository.parseResponse(body),
            throwsA(isA<ServerResponseFailure>()));
      }
    });

    test('reports connection errors', () async {
      final repository = SoapQuotaRepository(
        client: MockClient((_) => throw const SocketException('sin red')),
        certsDir: dir.path,
      );

      await expectLater(repository.fetch(sampleProfile()),
          throwsA(isA<NetworkFailure>()));
    });
  });

  test('change password fails on a non 200 response', () async {
    final repository = HttpAccountRepository(
      client: MockClient((_) async => http.Response('error', 500)),
      certsDir: dir.path,
    );

    await expectLater(
      repository.changePassword(const PasswordChange(
        username: 'u',
        current: 'a',
        replacement: 'b',
        confirmation: 'b',
      )),
      throwsA(isA<ServerResponseFailure>()),
    );
  });

  group('cntlm configuration', () {
    const hashes = CntlmHashes({'PassNT': 'ABC'});

    test('only holds hashes and uses the profile values', () {
      final config = buildCntlmConfig(sampleProfile(), hashes);

      expect(config, isNot(contains('cl&ve')));
      expect(config, isNot(contains('Password')));
      expect(config, contains('PassNT\tABC'));
      expect(config, contains('Listen\t127.0.0.1:3128'));
      expect(config, contains('NoProxy\tlocalhost, 10.*\n'));
    });

    test('stays on the given address and local-only by default', () {
      final config = buildCntlmConfig(
          sampleProfile().copyWith(allowedHosts: ['192.168.1.0/24']), hashes);

      expect(config, contains('Gateway\tno'));
      expect(config, isNot(contains('192.168.1.0/24')));
    });

    test('gateway mode binds every interface and keeps the deny rule last', () {
      final config = buildCntlmConfig(
        sampleProfile()
            .copyWith(gateway: true, allowedHosts: ['192.168.1.0/24']),
        hashes,
      );

      expect(config, contains('Gateway\tyes'));
      expect(config, contains('Listen\t3128\n'));
      expect(
        config,
        endsWith('Allow\t127.0.0.1\nAllow\t192.168.1.0/24\nDeny\t0/0\n'),
      );
    });

    test('parses the output of cntlm -H', () {
      final parsed = CntlmHashes.parse('Password: \n'
          'PassLM          AA11\n'
          'PassNT          BB22\n'
          "PassNTLMv2      CC33    # Only for user 'u', domain 'd'\n");

      expect(parsed.isComplete, isTrue);
      expect(parsed.values['PassNTLMv2'], 'CC33');
    });
  });

  test('the certificates bundled with the app can be loaded', () {
    final files = Directory('assets/certs').listSync().whereType<File>();
    expect(files, isNotEmpty);
    for (final file in files) {
      SecurityContext().setTrustedCertificates(file.path);
    }
  });

  group('secure HTTP client', () {
    late HttpServer server;
    late String caPath;

    setUp(() async {
      caPath = '${dir.path}/server.pem';
      final key = '${dir.path}/server.key';
      final result = await Process.run('openssl', [
        'req', '-x509', '-newkey', 'rsa:2048', '-nodes', //
        '-keyout', key, '-out', caPath, '-days', '1',
        '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost',
      ]);
      expect(result.exitCode, 0);
      server = await HttpServer.bindSecure(
        'localhost',
        0,
        SecurityContext()
          ..useCertificateChain(caPath)
          ..usePrivateKey(key),
      );
      server.listen((request) {
        request.response
          ..write('ok')
          ..close();
      });
    });

    tearDown(() => server.close(force: true));

    Uri url() => Uri.parse('https://localhost:${server.port}/');

    test('rejects an untrusted certificate', () async {
      final certs = await Directory('${dir.path}/empty').create();
      final client = createSecureHttpClient(certs.path);
      addTearDown(client.close);

      await expectLater(
        guardNetwork(certs.path, () => client.get(url())),
        throwsA(isA<TlsFailure>()),
      );
    });

    test('accepts a certificate bundled with the app', () async {
      final certs = await Directory('${dir.path}/empty').create();
      final client = createSecureHttpClient(
        certs.path,
        bundled: [File(caPath).readAsBytesSync()],
      );
      addTearDown(client.close);

      final response = await guardNetwork(certs.path, () => client.get(url()));

      expect(response.body, 'ok');
    });

    test('accepts a CA added to the certificates directory', () async {
      final certs = await Directory('${dir.path}/certs').create();
      File(caPath).copySync('${certs.path}/server.pem');
      File('${certs.path}/invalido.pem').writeAsStringSync('basura');
      final client = createSecureHttpClient(certs.path);
      addTearDown(client.close);

      final response = await guardNetwork(certs.path, () => client.get(url()));

      expect(response.body, 'ok');
    });
  });

  test('profile JSON never contains the password', () async {
    final created = await repository.create('Perfil');
    await repository.save(created.copyWith(password: 'x'));
    final json = jsonDecode(File('${dir.path}/perfil.conf').readAsStringSync());
    expect((json as Map).containsKey('pass'), isFalse);
  });
}
