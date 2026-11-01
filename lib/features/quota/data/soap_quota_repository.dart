import 'dart:convert';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/network/secure_http_client.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/quota/domain/quota.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class SoapQuotaRepository implements QuotaRepository {
  const SoapQuotaRepository({required this.client, required this.certsDir});

  static final _endpoint =
      Uri.parse('https://cuotas.uci.cu/servicios/v1/InetCuotasWS.php?WSDL');

  final http.Client client;
  final String certsDir;

  @override
  Future<Quota> fetch(Profile profile) async {
    final response = await guardNetwork(
      certsDir,
      () => client.post(_endpoint, body: utf8.encode(buildRequest(profile))),
    );
    return parseResponse(response.body);
  }

  static String buildRequest(Profile profile) => '''
<soap-env:Envelope xmlns:soap-env="http://schemas.xmlsoap.org/soap/envelope/">
  <soap-env:Body>
    <ns0:ObtenerCuota xmlns:ns0="urn:InetCuotasWS">
      <usuario>${_escape(profile.username)}</usuario>
      <clave>${_escape(profile.password)}</clave>
      <dominio>${_escape(profile.domain)}</dominio>
    </ns0:ObtenerCuota>
  </soap-env:Body>
</soap-env:Envelope>
''';

  static String _escape(String value) => XmlText(value).toXmlString();

  static Quota parseResponse(String body) {
    try {
      final root = XmlDocument.parse(body).rootElement;
      return Quota(
        total: double.parse(root.findAllElements('cuota').first.innerText),
        used: double.parse(root.findAllElements('cuota_usada').first.innerText),
      );
    } on XmlException {
      throw _unexpected;
    } on FormatException {
      throw _unexpected;
    } on StateError {
      throw _unexpected;
    }
  }

  static const _unexpected = ServerResponseFailure(
      'No se pudo leer la cuota, compruebe el usuario y la contraseña');
}
