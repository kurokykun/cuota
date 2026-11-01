import 'dart:async';
import 'dart:io';

import 'package:cuota/core/errors/failures.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const requestTimeout = Duration(seconds: 15);

const _bundledCertsPrefix = 'assets/certs/';

/// Certificates shipped with the app, for servers of the university whose
/// private CA no system trusts.
Future<List<Uint8List>> loadBundledCertificates() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final assets = manifest
      .listAssets()
      .where((a) => a.startsWith(_bundledCertsPrefix) && a.endsWith('.pem'));
  return [
    for (final asset in assets)
      (await rootBundle.load(asset)).buffer.asUint8List(),
  ];
}

/// HTTP client that verifies certificates against the system roots, the
/// [bundled] ones and any `*.pem` found in [certsDir]. Certificates are never
/// skipped: the requests of this app carry the user's password.
http.Client createSecureHttpClient(
  String certsDir, {
  List<Uint8List> bundled = const [],
}) {
  final context = SecurityContext(withTrustedRoots: true);
  for (final certificate in bundled) {
    context.setTrustedCertificatesBytes(certificate);
  }
  final dir = Directory(certsDir);
  if (dir.existsSync()) {
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.pem')) continue;
      try {
        context.setTrustedCertificates(file.path);
      } on TlsException {
        // An invalid file must not disable the remaining trusted roots.
      }
    }
  }
  final client = HttpClient(context: context)
    ..connectionTimeout = requestTimeout;
  return IOClient(client);
}

/// Runs [request] translating transport errors into [Failure]s.
Future<T> guardNetwork<T>(
  String certsDir,
  Future<T> Function() request,
) async {
  try {
    return await request().timeout(requestTimeout);
  } on TimeoutException {
    throw const NetworkFailure('El servidor tardó demasiado en responder, inténtelo más tarde');
  } on HandshakeException {
    throw TlsFailure(_tlsMessage(certsDir));
  } on TlsException {
    throw TlsFailure(_tlsMessage(certsDir));
  } on http.ClientException catch (e) {
    // IOClient wraps socket errors but keeps the handshake reason in the text.
    if (e.message.contains('CERTIFICATE') || e.message.contains('Handshake')) {
      throw TlsFailure(_tlsMessage(certsDir));
    }
    throw const NetworkFailure(_noConnection);
  } on SocketException {
    throw const NetworkFailure(_noConnection);
  }
}

const _noConnection =
    'No se pudo conectar con el servidor. ¿Está conectado a la red de la UCI?';

// The folder of an Android app cannot be reached by the user.
String _tlsMessage(String certsDir) => Platform.isAndroid
    ? 'No se pudo confirmar que el servidor sea seguro. Puede que el '
          'certificado haya cambiado: actualice la aplicación'
    : 'No se pudo confirmar que el servidor sea seguro. Puede que el '
          'certificado haya cambiado: actualice la aplicación o copie el nuevo '
          '.pem a $certsDir';
