import 'package:cuota/core/config/app_paths.dart';
import 'package:cuota/core/presentation/app_shell.dart';
import 'package:cuota/core/providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final paths = await AppPaths.resolve();

  runApp(ProviderScope(
    // Failures are reported to the user, there is nothing to retry blindly.
    retry: (retryCount, error) => null,
    overrides: [appPathsProvider.overrideWithValue(paths)],
    child: const MyApp(),
  ));

  const size = Size(420, 640);
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Cuota',
      size: size,
      minimumSize: size,
      maximumSize: size,
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Cuota',
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: SystemTheme.accentColor.accent.toAccentColor(),
      ),
      home: const AppShell(),
    );
  }
}
