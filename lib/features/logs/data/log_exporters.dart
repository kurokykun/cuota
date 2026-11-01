import 'dart:io';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/features/logs/domain/log_entry.dart';
import 'package:flutter/services.dart';

/// Saves to the downloads folder of the user.
class DownloadsLogExporter implements LogExporter {
  const DownloadsLogExporter();

  Future<String> _downloadsDir() async {
    if (Platform.isWindows) {
      return '${Platform.environment['UserProfile']}\\Downloads';
    }
    try {
      // The folder is localized, for example ~/Descargas.
      final result = await Process.run('xdg-user-dir', ['DOWNLOAD']);
      final path = (result.stdout as String).trim();
      if (result.exitCode == 0 && path.isNotEmpty) return path;
    } on ProcessException {
      // Not installed everywhere.
    }
    return Platform.environment['HOME'] ?? Directory.current.path;
  }

  @override
  Future<String> save(String fileName, String contents) async {
    try {
      final dir = await Directory(await _downloadsDir()).create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(contents, flush: true);
      return file.path;
    } on FileSystemException {
      throw const StorageFailure('No se pudo guardar el registro');
    }
  }
}

/// Android gives no direct access to the downloads folder, the native side goes
/// through MediaStore, which needs no permissions.
class AndroidLogExporter implements LogExporter {
  const AndroidLogExporter();

  static const _channel = MethodChannel('cuota/vpn');

  @override
  Future<String> save(String fileName, String contents) async {
    try {
      final path = await _channel.invokeMethod<String>('saveLog', {
        'name': fileName,
        'contents': contents,
      });
      return path ?? fileName;
    } on PlatformException {
      throw const StorageFailure('No se pudo guardar el registro');
    }
  }
}
