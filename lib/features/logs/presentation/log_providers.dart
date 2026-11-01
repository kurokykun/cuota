import 'dart:io';

import 'package:cuota/features/logs/data/log_exporters.dart';
import 'package:cuota/features/logs/domain/log_entry.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:cuota/features/quota/presentation/quota_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final logExporterProvider = Provider<LogExporter>(
  (ref) => Platform.isAndroid
      ? const AndroidLogExporter()
      : const DownloadsLogExporter(),
);

final logControllerProvider =
    NotifierProvider<LogController, List<LogEntry>>(LogController.new);

/// Keeps what happened during this session, for the logs page and for reports.
class LogController extends Notifier<List<LogEntry>> {
  static const _maxEntries = 2000;

  /// Credentials to hide, the ones of the last profile used.
  Profile? _profile;

  @override
  List<LogEntry> build() {
    final lines = ref
        .watch(proxyGatewayProvider)
        .logLines
        .listen((line) => _add('cntlm', line));
    ref.onDispose(lines.cancel);

    ref.listen(proxyControllerProvider, (previous, status) {
      if (status.phase == previous?.phase && status.warning == previous?.warning) {
        return;
      }
      _onProxyStatus(status);
    });
    ref.listen(quotaControllerProvider, (previous, quota) {
      final error = quota.error;
      if (error != null && error != previous?.error) {
        _add('app', 'Cuota: $error', LogLevel.warning);
      }
    });
    return const [];
  }

  void _onProxyStatus(ProxyStatus status) {
    final profile = status.profile;
    if (profile != null) _profile = profile;
    switch (status.phase) {
      case ProxyPhase.starting:
        _add('app', 'Iniciando proxy: servidor ${profile?.upstreamHost}:'
            '${profile?.upstreamPort}, puerto local ${profile?.localPort}, '
            'compartir ${profile?.gateway ?? false ? 'sí' : 'no'}');
      case ProxyPhase.running:
        _add('app', 'Proxy activo');
      case ProxyPhase.stopping:
        _add('app', 'Deteniendo proxy');
      case ProxyPhase.stopped:
        _add('app', 'Proxy detenido');
    }
    if (status.error != null) _add('app', status.error!, LogLevel.error);
    if (status.warning != null) _add('app', status.warning!, LogLevel.warning);
  }

  void _add(String source, String message, [LogLevel level = LogLevel.info]) {
    final entry = LogEntry(
      time: DateTime.now(),
      source: source,
      level: level,
      message: sanitizeLogLine(
        message,
        username: _profile?.username,
        password: _profile?.password,
      ),
    );
    final entries = [...state, entry];
    state = entries.length > _maxEntries
        ? entries.sublist(entries.length - _maxEntries)
        : entries;
  }

  void clear() => state = const [];

  /// The whole log as the text of the exported file.
  String export() {
    return formatLogExport(
      state,
      now: DateTime.now(),
      system: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
  }
}
