import 'dart:async';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/proxy/data/cntlm_config.dart';
import 'package:cuota/features/proxy/domain/proxy.dart';
import 'package:flutter/services.dart';

/// Sends the traffic of the whole device through cntlm using a local VPN. The
/// native side lives in `android/app/src/main/kotlin`.
class AndroidVpnProxyGateway implements ProxyGateway {
  AndroidVpnProxyGateway() {
    _events.receiveBroadcastStream().listen((event) {
      final map = event as Map<Object?, Object?>;
      switch (map['type']) {
        case 'exit':
          _exits.add(map['message'] as String);
        case 'quota':
          _quota.add(null);
      }
    });
  }

  static const _methods = MethodChannel('cuota/vpn');
  static const _events = EventChannel('cuota/vpn/events');

  final _exits = StreamController<String>.broadcast();
  final _quota = StreamController<void>.broadcast();

  @override
  Stream<String> get unexpectedExits => _exits.stream;

  @override
  Stream<void> get quotaExhausted => _quota.stream;

  @override
  Future<String?> runningProfileId() =>
      _methods.invokeMethod<String>('runningProfileId');

  @override
  Future<void> start(Profile profile) async {
    try {
      final output = await _methods.invokeMethod<String>('computeHashes', {
        'username': profile.username,
        'domain': profile.domain,
        'password': profile.password,
      });
      final hashes = CntlmHashes.parse(output ?? '');
      if (!hashes.isComplete) {
        throw const ProxyStartFailure(
            'No se pudo preparar la contraseña, compruébela e inténtelo de nuevo');
      }
      await _methods.invokeMethod<void>('start', {
        'config': buildCntlmConfig(profile, hashes),
        'port': int.parse(profile.localPort),
        'profileId': profile.id,
      });
    } on PlatformException catch (e) {
      throw ProxyStartFailure(e.message ?? 'No se pudo iniciar el proxy');
    } on MissingPluginException {
      throw const ProxyStartFailure('No se pudo iniciar el proxy');
    }
  }

  @override
  Future<void> stop() => _methods.invokeMethod<void>('stop');
}
