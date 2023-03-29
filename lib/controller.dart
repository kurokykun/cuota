import 'dart:io';
import 'package:get/state_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuota/profile_entity.dart';

class Controller extends GetxController {
  late var prefs;
  String path = '';
  var profile_list = [].obs;
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
    for (var element in files.toList()) {
      String str = await element.readAsString();
      var profile = profilesFromJson(str);
      profile_list.add(profile);
    }
    print(profile_list);
  }
}
