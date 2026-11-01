import 'dart:async';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/providers.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/data/cntlm_proxy_gateway.dart';
import 'package:cuota/features/proxy/domain/proxy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final proxyGatewayProvider = Provider<ProxyGateway>(
  (ref) => CntlmProxyGateway(tempDir: ref.watch(appPathsProvider).tempDir),
);

enum ProxyPhase { stopped, starting, running, stopping }

class ProxyStatus {
  const ProxyStatus(this.phase, {this.profile, this.error, this.warning});

  final ProxyPhase phase;

  /// The profile in use while the proxy is starting or running.
  final Profile? profile;

  /// Why the proxy is stopped, when it was not requested by the user.
  final String? error;

  /// Something to report although the proxy is running.
  final String? warning;

  /// Profiles cannot be changed unless the proxy is fully stopped.
  bool get isBusy => phase != ProxyPhase.stopped;
}

final proxyControllerProvider =
    NotifierProvider<ProxyController, ProxyStatus>(ProxyController.new);

class ProxyController extends Notifier<ProxyStatus> {
  @override
  ProxyStatus build() {
    final exits = ref.watch(proxyGatewayProvider).unexpectedExits.listen(
          (reason) => state = ProxyStatus(ProxyPhase.stopped, error: reason),
        );
    ref.onDispose(exits.cancel);
    return const ProxyStatus(ProxyPhase.stopped);
  }

  Future<void> start(Profile profile) async {
    if (state.isBusy) return;
    state = ProxyStatus(ProxyPhase.starting, profile: profile);
    try {
      final warning = await StartProxy(
        ref.read(profileRepositoryProvider),
        ref.read(proxyGatewayProvider),
      )(profile);
      ref.read(profilesControllerProvider.notifier).replace(profile);
      state =
          ProxyStatus(ProxyPhase.running, profile: profile, warning: warning);
    } on Failure catch (failure) {
      state = ProxyStatus(ProxyPhase.stopped, error: failure.message);
    }
  }

  Future<void> stop() async {
    if (state.phase != ProxyPhase.running) return;
    state = ProxyStatus(ProxyPhase.stopping, profile: state.profile);
    await StopProxy(ref.read(proxyGatewayProvider))();
    state = const ProxyStatus(ProxyPhase.stopped);
  }
}
