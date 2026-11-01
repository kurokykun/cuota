import 'dart:convert';
import 'dart:io';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/platform/file_permissions.dart';
import 'package:cuota/features/profiles/data/profile_json.dart';
import 'package:cuota/features/profiles/data/secret_store.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_repository.dart';

/// Stores each profile as `<id>.conf` and its password in a [SecretStore].
class FileProfileRepository implements ProfileRepository {
  const FileProfileRepository({required this.directory, required this.secrets});

  static const _extension = '.conf';

  final String directory;
  final SecretStore secrets;

  File _file(String id) =>
      File('$directory${Platform.pathSeparator}$id$_extension');

  String _secretKey(String id) => 'cuota.profile.$id';

  @override
  Future<ProfileCatalog> loadAll() async {
    final profiles = <Profile>[];
    final corrupt = <String>[];
    var secretsAvailable = true;

    try {
      final dir = await ensurePrivateDirectory(directory);
      final entities = await dir.list().toList();
      final files = entities
          .whereType<File>()
          .where((file) => file.path.endsWith(_extension))
          .toList()
        ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      for (final file in files) {
        final fileName = file.uri.pathSegments.last;
        final id =
            fileName.substring(0, fileName.length - _extension.length);

        final Map<String, dynamic> json;
        final Profile parsed;
        try {
          json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          parsed = ProfileJson.fromJson(id, json);
        } on Object {
          corrupt.add(fileName);
          continue;
        }

        try {
          profiles.add(await _withPassword(parsed, json, file));
        } on SecretStorageFailure {
          secretsAvailable = false;
          // A legacy password stays in memory and in its file until it can be
          // moved to the keyring, otherwise the profile would lose it.
          profiles.add(parsed);
        }
      }
    } on FileSystemException {
      throw StorageFailure('No se pudieron leer los perfiles de $directory');
    }

    profiles.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ProfileCatalog(
      profiles: profiles,
      corruptFiles: corrupt,
      secretsAvailable: secretsAvailable,
    );
  }

  /// Resolves the password, moving it out of the file when it still has one.
  Future<Profile> _withPassword(
    Profile parsed,
    Map<String, dynamic> json,
    File file,
  ) async {
    if (json.containsKey(ProfileJson.legacyPasswordKey)) {
      await secrets.write(_secretKey(parsed.id), parsed.password);
      await _writeProfile(parsed);
      return parsed;
    }
    await restrictToOwner(file.path);
    final password = await secrets.read(_secretKey(parsed.id));
    return parsed.copyWith(password: password ?? '');
  }

  @override
  Future<Profile> create(
    String name, {
    ProfileColor color = ProfileColor.teal,
  }) async {
    final profile = Profile(
      id: await _newId(name),
      name: name,
      color: color,
      username: '',
      password: '',
      localAddress: '127.0.0.1',
      localPort: '3128',
      upstreamHost: '10.0.0.1',
      upstreamPort: '8080',
      domain: 'uci.cu',
      noProxy: const ['localhost', '127.0.0.*', '10.*', '192.168.*', '*uci.cu'],
      gateway: false,
    );
    // Do not inherit a leftover password from a deleted profile with this id.
    try {
      await secrets.delete(_secretKey(profile.id));
    } on SecretStorageFailure {
      // Reported when the credentials are saved.
    }
    await _writeProfile(profile);
    return profile;
  }

  /// File names come from a slug of [name], which can contain any character.
  Future<String> _newId(String name) async {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'perfil' : slug;
    var id = base;
    for (var suffix = 2; await _file(id).exists(); suffix++) {
      id = '$base-$suffix';
    }
    return id;
  }

  @override
  Future<void> save(Profile profile) async {
    // Keyring first: on failure the stored file, which may still hold a legacy
    // password, is left untouched.
    final key = _secretKey(profile.id);
    if (profile.password.isEmpty) {
      await secrets.delete(key);
    } else {
      await secrets.write(key, profile.password);
    }
    await _writeProfile(profile);
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _file(id).delete();
    } on FileSystemException {
      throw const StorageFailure('No se pudo eliminar el perfil');
    }
    try {
      await secrets.delete(_secretKey(id));
    } on SecretStorageFailure {
      // The profile is gone. A leftover entry is overwritten if the id is
      // reused, see [create].
    }
  }

  Future<void> _writeProfile(Profile profile) async {
    try {
      await ensurePrivateDirectory(directory);
      await writePrivateFile(
        _file(profile.id).path,
        jsonEncode(ProfileJson.toJson(profile)),
      );
    } on FileSystemException {
      throw StorageFailure('No se pudo guardar el perfil "${profile.name}"');
    }
  }
}
