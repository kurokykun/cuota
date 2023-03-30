import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/state_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuota/profile_entity.dart';
import 'package:dartdap/dartdap.dart';

class Controller extends GetxController {
  late var prefs;
  String path = '';
  var profile_list = [].obs;
  List<File> file_list = [];

  getIconColor(Profiles profile) {
    if (profile.color == "blue") {
      return Colors.blue;
    } else if (profile.color == "black") {
      return Colors.black;
    } else if (profile.color == "green") {
      return Colors.green;
    } else if (profile.color == "grey") {
      return Colors.grey;
    } else if (profile.color == "magenta") {
      return Colors.magenta;
    } else if (profile.color == "orange") {
      return Colors.orange;
    } else if (profile.color == "purple") {
      return Colors.purple;
    } else if (profile.color == "red") {
      return Colors.red;
    } else if (profile.color == "teal") {
      return Colors.teal;
    } else if (profile.color == "yellow") {
      return Colors.yellow;
    }
  }

  setIconColor(AccentColor color, int index) async {
    if (color == Colors.blue) {
      profile_list[index].color = "blue";
    } else if (color == Colors.red) {
      profile_list[index].color = "red";
    } else if (color == Colors.black) {
      profile_list[index].color = "black";
    } else if (color == Colors.green) {
      profile_list[index].color = "green";
    } else if (color == Colors.grey) {
      profile_list[index].color = "grey";
    } else if (color == Colors.magenta) {
      profile_list[index].color = "magenta";
    } else if (color == Colors.orange) {
      profile_list[index].color = "orange";
    } else if (color == Colors.purple) {
      profile_list[index].color = "purple";
    } else if (color == Colors.teal) {
      profile_list[index].color = "teal";
    } else if (color == Colors.yellow) {
      profile_list[index].color = "yellow";
    }
    await file_list[index].writeAsString(profilesToJson(profile_list[index]));
  }

  initial_profile() async {
    Map<String, String> envVars = Platform.environment;
    prefs = await SharedPreferences.getInstance();
    try {
      String first_time = await prefs.getString('first_time');
      path = await prefs.getString('path');
    } catch (e) {
      await prefs.setString("first_time", '');
      if (Platform.isMacOS) {
        String? home = envVars['HOME'];
        await prefs.setString("path", '$home/Cuota');
        path = await prefs.getString('path');
        var dir = await new File("$path/default_profile.conf")
            .create(recursive: true);
      } else if (Platform.isLinux) {
        String? home = envVars['HOME'];
        await prefs.setString("path", '$home/Cuota');
        path = await prefs.getString('path');
        var dir = await new File("$path/default_profile.conf")
            .create(recursive: true);
      } else if (Platform.isWindows) {
        String? home = envVars['UserProfile'];
        await prefs.setString("path", '$home\\Cuota');
        path = await prefs.getString('path');
        var dir = await new File("$path\\default_profile.conf")
            .create(recursive: true);
      }
    }
  }

  load_profiles() async {
    var dir = Directory('$path');
    profile_list.value = [];
    final List<FileSystemEntity> entities = await dir.list().toList();
    final Iterable<File> files = entities.whereType<File>();
    for (File element in files.toList()) {
      file_list.add(element);
      String str = await element.readAsString();
      var profile = profilesFromJson(str);
      profile_list.add(profile);
    }
    print(profile_list);
  }

  void test() async {
    var connection = LdapConnection(
        host: "ldap.uci.cu", ssl: false, port: 389, bindDN: "", password: "");
    try {
      await connection.open();
      await connection.bind();
      var a = await connection.search("uid=mamolina,OU=people,DC=uci,DC=cu",
          Filter.present('objectClass'), ['dc', 'objectClass']);
      await for (var entry in a.stream) {
        // Processing stream of SearchEntry
        print('dn: ${entry.dn}');

        // Getting all attributes returned
      }
    } catch (e) {
      print(e);
    }
  }
}
