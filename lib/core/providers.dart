import 'package:cuota/core/config/app_paths.dart';
import 'package:cuota/core/network/secure_http_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Resolved before the app starts and injected through a provider override.
final appPathsProvider = Provider<AppPaths>(
  (ref) => throw UnimplementedError('appPathsProvider must be overridden'),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = createSecureHttpClient(ref.watch(appPathsProvider).certsDir);
  ref.onDispose(client.close);
  return client;
});
