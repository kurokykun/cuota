import 'package:dartdap/dartdap.dart';

void test() async {
  var connection = LdapConnection(
      host: "ldap.uci.cu",
      ssl: false,
      port: 389,
      bindDN: "uid=%1,OU=people,DC=uci,DC=cu");
  try {
    await connection.open();
    await connection.bind();
  } catch (e) {}
}
