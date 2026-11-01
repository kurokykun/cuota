import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locations of the files owned by the app.
class AppPaths {
  const AppPaths({required this.root, this.isFirstRun = false});

  static const _pathKey = 'path';

  /// Directory with one `.conf` file per profile.
  final String root;

  /// Whether no data directory was configured before this launch.
  final bool isFirstRun;

  String get tempDir => '$root${Platform.pathSeparator}temp';

  /// Extra CA certificates (`*.pem`) trusted for HTTPS requests.
  String get certsDir => '$root${Platform.pathSeparator}certs';

  static Future<AppPaths> resolve() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_pathKey);
    if (saved != null) return AppPaths(root: saved);

    final env = Platform.environment;
    final home = Platform.isWindows ? env['UserProfile'] : env['HOME'];
    final root = Platform.isAndroid
        ? '${(await getApplicationSupportDirectory()).path}/Cuota'
        : '$home${Platform.pathSeparator}Cuota';
    await prefs.setString(_pathKey, root);
    return AppPaths(root: root, isFirstRun: true);
  }
}
