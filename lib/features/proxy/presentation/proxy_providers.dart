import 'dart:async';
import 'dart:io';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/providers.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/data/android_vpn_proxy_gateway.dart';
import 'package:cuota/features/proxy/data/cntlm_proxy_gateway.dart';
import 'package:cuota/features/proxy/domain/proxy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final proxyGatewayProvider = Provider<ProxyGateway>(
  (ref) => Platform.isAndroid
      ? AndroidVpnProxyGateway()
      : CntlmProxyGateway(tempDir: ref.watch(appPathsProvider).tempDir),
);

/// IPv4 addresses other machines can use to reach this one.
final localAddressesProvider = FutureProvider<List<String>>((ref) async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses) address.address,
  ];
});

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
    final quota = ref.watch(proxyGatewayProvider).quotaExhausted.listen((_) {
      if (state.phase != ProxyPhase.running || state.warning == _noQuota) return;
      state = ProxyStatus(
        ProxyPhase.running,
        profile: state.profile,
        warning: _noQuota,
      );
    });
    ref.onDispose(exits.cancel);
    ref.onDispose(quota.cancel);
    return const ProxyStatus(ProxyPhase.stopped);
  }

  static const _noQuota = 'Sin cuota: el proxy de la universidad está '
      'bloqueando la navegación';

  /// Adopts a proxy still running from before the UI was opened.
  Future<void> syncWithGateway() async {
    final id = await ref.read(proxyGatewayProvider).runningProfileId();
    if (id == null || state.isBusy) return;
    final catalog = await ref.read(profilesControllerProvider.future);
    final profile = catalog.profiles.where((p) => p.id == id).firstOrNull;
    if (profile != null) {
      state = ProxyStatus(ProxyPhase.running, profile: profile);
    }
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
