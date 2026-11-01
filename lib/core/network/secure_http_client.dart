import 'dart:async';
import 'dart:io';

import 'package:cuota/core/errors/failures.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const requestTimeout = Duration(seconds: 15);

/// HTTP client that verifies certificates against the system roots plus any
/// `*.pem` CA found in [certsDir]. Certificates are never skipped: the requests
/// of this app carry the user's password.
http.Client createSecureHttpClient(String certsDir) {
  final context = SecurityContext(withTrustedRoots: true);
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

String _tlsMessage(String certsDir) =>
    'No se pudo confirmar que el servidor sea seguro. Si su institución usa un '
    'certificado propio, copie el archivo .pem a $certsDir';
