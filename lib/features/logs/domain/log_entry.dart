enum LogLevel { info, warning, error }

class LogEntry {
  const LogEntry({
    required this.time,
    required this.source,
    required this.message,
    this.level = LogLevel.info,
  });

  final DateTime time;

  /// Where it comes from: the app itself or cntlm.
  final String source;
  final String message;
  final LogLevel level;
}

abstract interface class LogExporter {
  /// Saves [contents] and returns where the user can find the file.
  Future<String> save(String fileName, String contents);
}

String _two(int value) => value.toString().padLeft(2, '0');

String formatLogTime(DateTime time) =>
    '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';

String _date(DateTime time) =>
    '${time.year}-${_two(time.month)}-${_two(time.day)}';

/// The name has no spaces or colons, so it is valid on every system.
String logFileName(DateTime now) {
  final date = _date(now).replaceAll('-', '');
  final time = formatLogTime(now).replaceAll(':', '');
  return 'cuota-registro-$date-$time.txt';
}

String formatLogExport(
  List<LogEntry> entries, {
  required DateTime now,
  required String system,
}) {
  final buffer = StringBuffer()
    ..writeln('Registro de Cuota')
    ..writeln('Generado: ${_date(now)} ${formatLogTime(now)}')
    ..writeln('Sistema: $system')
    ..writeln();
  for (final entry in entries) {
    final level =
        entry.level == LogLevel.info ? '' : '${entry.level.name.toUpperCase()}: ';
    buffer.writeln('${_date(entry.time)} ${formatLogTime(entry.time)} '
        '[${entry.source}] $level${entry.message}');
  }
  return buffer.toString();
}

/// Removes what must not end up in a file meant to be shared.
String sanitizeLogLine(String line, {String? username, String? password}) {
  var result = line.replaceAll(RegExp(r'\b[0-9A-Fa-f]{16,}\b'), '[oculto]');
  if (password != null && password.isNotEmpty) {
    result = result.replaceAll(password, '[oculto]');
  }
  if (username != null && username.isNotEmpty) {
    result = result.replaceAll(username, '[usuario]');
  }
  return result;
}
