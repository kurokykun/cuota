import 'dart:convert';
import 'dart:io';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/features/proxy/data/cntlm_proxy_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Runs against the real cntlm binary.
void main() {
  final hasCntlm = !Platform.isWindows &&
      Process.runSync('which', ['cntlm']).exitCode == 0;

  late Directory dir;
  late CntlmProxyGateway gateway;

  Future<int> freePort() async {
    final socket = await ServerSocket.bind('127.0.0.1', 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<bool> listening(int port) async {
    try {
      (await Socket.connect('127.0.0.1', port)).destroy();
      return true;
    } on SocketException {
      return false;
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cuota_cntlm');
    gateway = CntlmProxyGateway(tempDir: dir.path);
  });

  tearDown(() async {
    await gateway.stop();
    await dir.delete(recursive: true);
  });

  test('starts, leaves no credentials behind and stops', () async {
    final port = await freePort();
    final profile = sampleProfile(localPort: '$port');

    await gateway.start(profile);

    expect(await listening(port), isTrue);
    expect(File('${dir.path}/cntlm.conf').existsSync(), isFalse);
    expect(File('${dir.path}/empty.conf').existsSync(), isFalse);

    await gateway.stop();

    expect(await listening(port), isFalse);
    expect(dir.listSync(), isEmpty);
  }, skip: !hasCntlm);

  test('can be restarted', () async {
    final port = await freePort();
    final profile = sampleProfile(localPort: '$port');

    await gateway.start(profile);
    await gateway.stop();
    await gateway.start(profile);

    expect(await listening(port), isTrue);
  }, skip: !hasCntlm);

  test('reports a port already in use', () async {
    final busy = await ServerSocket.bind('127.0.0.1', 0);
    addTearDown(busy.close);

    await expectLater(
      gateway.start(sampleProfile(localPort: '${busy.port}')),
      throwsA(isA<ProxyStartFailure>()
          .having((f) => f.message, 'message', contains('no está disponible'))),
    );
  }, skip: !hasCntlm);

  test('reports a missing binary', () async {
    final missing = CntlmProxyGateway(
      tempDir: dir.path,
      executable: '${dir.path}/no-existe',
    );

    await expectLater(
      missing.start(sampleProfile(localPort: '${await freePort()}')),
      throwsA(isA<ProxyStartFailure>()
          .having((f) => f.message, 'message', contains('No se encontró'))),
    );
  });

  test('reports when the proxy dies on its own', () async {
    final port = await freePort();
    await gateway.start(sampleProfile(localPort: '$port'));
    final exit = gateway.unexpectedExits.first;

    final pid = int.parse(File('${dir.path}/cntlm.pid').readAsStringSync());
    Process.killPid(pid, ProcessSignal.sigkill);

    expect(await exit.timeout(const Duration(seconds: 5)),
        contains('terminó inesperadamente'));
    // A new start must work right after the crash.
    await gateway.start(sampleProfile(localPort: '$port'));
    expect(await listening(port), isTrue);
  }, skip: !hasCntlm);

  test('a new instance kills the orphan of a previous run', () async {
    final port = await freePort();
    await gateway.start(sampleProfile(localPort: '$port'));

    final next = CntlmProxyGateway(tempDir: dir.path);
    await next.recover();

    expect(await listening(port), isFalse);
    expect(File('${dir.path}/cntlm.pid').existsSync(), isFalse);
  }, skip: !hasCntlm);

  test('the password never reaches the process arguments', () async {
    final port = await freePort();
    await gateway.start(sampleProfile(localPort: '$port', password: 'S3creta!'));

    final pid = File('${dir.path}/cntlm.pid').readAsStringSync().trim();
    final cmdline = File('/proc/$pid/cmdline').readAsBytesSync();
    expect(utf8.decode(cmdline, allowMalformed: true),
        isNot(contains('S3creta!')));
  }, skip: !hasCntlm);
}
