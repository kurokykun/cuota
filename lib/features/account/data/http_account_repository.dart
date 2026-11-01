import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/network/secure_http_client.dart';
import 'package:cuota/features/account/domain/account.dart';
import 'package:http/http.dart' as http;

class HttpAccountRepository implements AccountRepository {
  const HttpAccountRepository({required this.client, required this.certsDir});

  static final _endpoint = Uri.parse('https://drst.uci.cu/change-password');

  final http.Client client;
  final String certsDir;

  @override
  Future<void> changePassword(PasswordChange change) async {
    final response = await guardNetwork(
      certsDir,
      () => client.post(_endpoint, body: {
        'user': change.username,
        'old': change.current,
        'new': change.replacement,
        'confirm': change.confirmation,
      }),
    );
    if (response.statusCode != 200) {
      throw const ServerResponseFailure(
          'Ha ocurrido un error durante el cambio de contraseña');
    }
  }
}
