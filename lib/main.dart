import 'dart:io';

import 'package:cuota/controller.dart';
import 'package:cuota/home.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:get/get.dart';
import 'package:system_theme/system_theme.dart';

void main() async {
  Controller controller = Get.put(Controller());
  await controller.initial_profile();
  await controller.initSystemTray();
  HttpOverrides.global = MyHttpOverrides();

  runApp(const MyApp());
  doWhenWindowReady(() {
    const initialSize = Size(400, 600);
    appWindow.minSize = initialSize;
    appWindow.maxSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: SystemTheme.accentColor.accent.toAccentColor(),
      ),
      home: Home(),
    );
  }
}
