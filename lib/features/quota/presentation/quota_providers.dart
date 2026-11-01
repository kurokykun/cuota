import 'dart:async';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/providers.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:cuota/features/quota/data/soap_quota_repository.dart';
import 'package:cuota/features/quota/domain/quota.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quotaRepositoryProvider = Provider<QuotaRepository>(
  (ref) => SoapQuotaRepository(
    client: ref.watch(httpClientProvider),
    certsDir: ref.watch(appPathsProvider).certsDir,
  ),
);

class QuotaState {
  const QuotaState({this.quota, this.error});

  /// Last known value, kept while a refresh fails.
  final Quota? quota;
  final String? error;
}

final quotaControllerProvider =
    NotifierProvider<QuotaController, QuotaState>(QuotaController.new);

/// Refreshes the quota periodically while the proxy is running.
class QuotaController extends Notifier<QuotaState> {
  static const refreshInterval = Duration(minutes: 1);

  Timer? _timer;

  /// Discards the responses of requests started before the last stop.
  int _generation = 0;

  @override
  QuotaState build() {
    ref.listen(proxyControllerProvider, (previous, status) {
      if (status.phase == ProxyPhase.running &&
          previous?.phase != ProxyPhase.running) {
        _startPolling(status.profile!);
      } else if (status.phase != ProxyPhase.running) {
        _stopPolling();
      }
    });
    ref.onDispose(_stopPolling);
    return const QuotaState();
  }

  void reset() {
    _stopPolling();
    state = const QuotaState();
  }

  void _startPolling(Profile profile) {
    _stopPolling();
    unawaited(_refresh(profile));
    _timer = Timer.periodic(refreshInterval, (_) => _refresh(profile));
  }

  void _stopPolling() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _refresh(Profile profile) async {
    final generation = _generation;
    QuotaState next;
    try {
      next = QuotaState(
        quota: await GetQuota(ref.read(quotaRepositoryProvider))(profile),
      );
    } on Failure catch (failure) {
      next = QuotaState(quota: state.quota, error: failure.message);
    }
    if (generation == _generation) state = next;
  }
}
