import 'dart:io';

/// Makes [path] accessible only by the current user. No-op on Windows, where
/// the user profile is already private.
Future<void> restrictToOwner(String path) async {
  if (Platform.isWindows) return;
  final isDirectory = await FileSystemEntity.isDirectory(path);
  await Process.run('chmod', [isDirectory ? '700' : '600', path]);
}

/// Creates [directory] if needed, accessible only by the current user.
Future<Directory> ensurePrivateDirectory(String directory) async {
  final dir = await Directory(directory).create(recursive: true);
  await restrictToOwner(dir.path);
  return dir;
}

/// Writes [contents] to [path], restricting the file before any data lands.
Future<void> writePrivateFile(String path, String contents) async {
  final file = await File(path).create(recursive: true);
  await restrictToOwner(path);
  await file.writeAsString(contents, flush: true);
}
