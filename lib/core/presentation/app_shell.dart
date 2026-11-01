import 'dart:async';
import 'dart:io';

import 'package:cuota/features/profiles/presentation/profiles_page.dart';
import 'package:cuota/features/proxy/data/cntlm_proxy_gateway.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

/// Window frame, system tray and process lifecycle of the app.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WindowListener, tray.TrayListener {
  final _signals = <StreamSubscription<ProcessSignal>>[];
  bool _quitting = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      unawaited(ref.read(proxyControllerProvider.notifier).syncWithGateway());
      return;
    }
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true));
    unawaited(_initTray());
    final gateway = ref.read(proxyGatewayProvider);
    if (gateway is CntlmProxyGateway) unawaited(gateway.recover());
    if (!Platform.isWindows) {
      for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
        _signals.add(signal.watch().listen((_) => _quit()));
      }
    }
  }

  @override
  void dispose() {
    if (!Platform.isAndroid) {
      windowManager.removeListener(this);
      tray.trayManager.removeListener(this);
    }
    for (final subscription in _signals) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<void> _initTray() async {
    try {
      tray.trayManager.addListener(this);
      await tray.trayManager
          .setIcon(switch (Platform.operatingSystem) {
        'windows' => 'images/app.ico',
        // Panels use plain glyphs, the app icon turns into a blur at their size.
        'linux' => 'images/tray.png',
        _ => 'images/app.png',
      });
      await tray.trayManager.setContextMenu(tray.Menu(items: [
        tray.MenuItem(label: 'Mostrar', onClick: (_) => _showWindow()),
        tray.MenuItem(label: 'Ocultar', onClick: (_) => windowManager.hide()),
        tray.MenuItem(label: 'Salir', onClick: (_) => _quit()),
      ]));
    } catch (e) {
      // The tray is optional, the app must still work without it.
      debugPrint('System tray unavailable: $e');
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Without a tray host the hidden window could not be brought back.
  Future<bool> _trayHostAvailable() async {
    if (!Platform.isLinux) return true;
    try {
      final result = await Process.run('gdbus', [
        'call',
        '--session',
        '--dest',
        'org.freedesktop.DBus',
        '--object-path',
        '/org/freedesktop/DBus',
        '--method',
        'org.freedesktop.DBus.NameHasOwner',
        'org.kde.StatusNotifierWatcher',
      ]);
      return (result.stdout as String).contains('true');
    } on ProcessException {
      return false;
    }
  }

  Future<void> _hideToTray() async {
    if (await _trayHostAvailable()) {
      await windowManager.hide();
    } else {
      await windowManager.minimize();
    }
  }

  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    await ref.read(proxyGatewayProvider).stop();
    await tray.trayManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() => unawaited(_hideToTray());

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayIconRightMouseDown() =>
      unawaited(tray.trayManager.popUpContextMenu());

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return ColoredBox(
        color: FluentTheme.of(context).scaffoldBackgroundColor,
        // Nothing else here reacts to the keyboard, it would cover the fields.
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: const SafeArea(child: ProfilesPage()),
        ),
      );
    }
    return ColoredBox(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: Column(children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              Expanded(
                child: DragToMoveArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Image.asset('images/app.png', width: 16, height: 16),
                        const SizedBox(width: 8),
                        Text('Cuota',
                            style: FluentTheme.of(context).typography.caption),
                      ],
                    ),
                  ),
                ),
              ),
              _WindowButton(
                icon: FluentIcons.chrome_minimize,
                onPressed: windowManager.minimize,
              ),
              _WindowButton(
                icon: FluentIcons.chrome_close,
                onPressed: _hideToTray,
              ),
            ],
          ),
        ),
        const Expanded(child: ProfilesPage()),
      ]),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: IconButton(
        icon: Icon(icon, size: 10),
        onPressed: onPressed,
      ),
    );
  }
}
