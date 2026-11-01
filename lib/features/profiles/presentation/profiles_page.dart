import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/profiles/presentation/profile_dialogs.dart';
import 'package:cuota/features/profiles/presentation/profile_header.dart';
import 'package:cuota/features/profiles/presentation/profile_view.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.read(messagesProvider.notifier);
    ref.listen(profilesControllerProvider, (previous, next) {
      if (previous?.value != null) return;
      final catalog = next.value;
      if (next.hasError) {
        messages.show(
          'No se pudieron cargar los perfiles',
          severity: InfoBarSeverity.error,
        );
      } else if (catalog != null && catalog.corruptFiles.isNotEmpty) {
        messages.show(
          'Algunos perfiles no se pudieron abrir: ${catalog.corruptFiles.join(', ')}',
          severity: InfoBarSeverity.warning,
        );
      } else if (catalog != null && !catalog.secretsAvailable) {
        messages.show(
          'No se pudieron leer las contraseñas guardadas. Escríbalas de nuevo para iniciar el proxy',
          severity: InfoBarSeverity.warning,
        );
      }
    });
    // Starting and stopping are already visible in the badge and the button,
    // only what the user could otherwise miss becomes a message.
    ref.listen(proxyControllerProvider, (previous, status) {
      if (status.phase == ProxyPhase.starting) {
        messages.dismiss();
      } else if (status.error != null) {
        messages.show(status.error!, severity: InfoBarSeverity.error);
      } else if (status.warning != null) {
        messages.show(status.warning!, severity: InfoBarSeverity.warning);
      }
    });

    final selected = ref.watch(selectedProfileProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      child: selected == null
          ? const _EmptyState(key: ValueKey('empty'))
          : ProfileView(
              key: ValueKey(selected.id),
              profileId: selected.id,
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ProfileMenuButton(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.globe, size: 35),
                SizedBox(height: 16),
                Text(
                  textAlign: TextAlign.center,
                  'Ningún perfil proxy creado todavía',
                  style: TextStyle(fontWeight: FontWeight.w300),
                ),
                SizedBox(height: 16),
                _CreateFirstProfileButton(),
              ],
            ),
          ),
        ),
        MessageStrip(),
        SizedBox(height: 16),
      ],
    );
  }
}

class _CreateFirstProfileButton extends StatelessWidget {
  const _CreateFirstProfileButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => showCreateProfileDialog(context),
      child: const Text('Crear perfil'),
    );
  }
}
