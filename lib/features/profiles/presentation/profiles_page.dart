import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/account/presentation/change_password_dialog.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/presentation/profile_colors.dart';
import 'package:cuota/features/profiles/presentation/profile_dialogs.dart';
import 'package:cuota/features/profiles/presentation/profile_form.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:cuota/features/quota/presentation/quota_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  /// Runs [action] unless the proxy is in use.
  void _whenIdle(BuildContext context, WidgetRef ref, VoidCallback action) {
    if (ref.read(proxyControllerProvider).isBusy) {
      showMessage(context, 'Primero debe detener el proxy',
          severity: InfoBarSeverity.error);
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(profilesControllerProvider, (previous, next) {
      if (previous?.value != null) return;
      final catalog = next.value;
      if (next.hasError) {
        showMessage(context, 'No se pudieron cargar los perfiles',
            severity: InfoBarSeverity.error);
      } else if (catalog != null && catalog.corruptFiles.isNotEmpty) {
        showMessage(context,
            'Archivos dañados omitidos: ${catalog.corruptFiles.join(', ')}',
            severity: InfoBarSeverity.warning);
      } else if (catalog != null && !catalog.secretsAvailable) {
        showMessage(context,
            'No se pudo acceder al llavero del sistema, revise las contraseñas',
            severity: InfoBarSeverity.warning);
      }
    });
    ref.listen(proxyControllerProvider, (previous, status) {
      if (status.error != null) {
        showMessage(context, status.error!, severity: InfoBarSeverity.error);
      } else if (status.phase == ProxyPhase.running &&
          previous?.phase != ProxyPhase.running) {
        showMessage(context, 'Proxy iniciado correctamente');
        if (status.warning != null) {
          showMessage(context, status.warning!,
              severity: InfoBarSeverity.warning);
        }
      } else if (status.phase == ProxyPhase.stopped &&
          previous?.phase == ProxyPhase.stopping) {
        showMessage(context, 'Proxy detenido correctamente');
      }
    });
    ref.listen(quotaControllerProvider, (previous, quota) {
      if (quota.error != null && quota.error != previous?.error) {
        showMessage(context, quota.error!, severity: InfoBarSeverity.warning);
      }
    });

    final profiles =
        ref.watch(profilesControllerProvider).value?.profiles ?? const [];
    final selected = ref.watch(selectedProfileProvider);

    return NavigationView(
      paneBodyBuilder: (item, body) => body ?? const _EmptyState(),
      pane: NavigationPane(
        displayMode: PaneDisplayMode.compact,
        selected: selected == null ? null : profiles.indexOf(selected),
        items: [
          for (final Profile profile in profiles)
            PaneItem(
              title: Text(profile.name),
              icon: Icon(FluentIcons.globe, color: profile.color.color),
              body: ProfileForm(
                key: ValueKey(profile.id),
                profileId: profile.id,
              ),
            ),
        ],
        footerItems: [
          PaneItem(
            enabled: selected != null,
            icon: const Icon(FluentIcons.delete),
            title: const Text('Eliminar Perfil'),
            body: Container(),
            onTap: selected == null
                ? null
                : () => _whenIdle(context, ref,
                    () => showDeleteProfileDialog(context, selected)),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.lock),
            title: const Text('Cambiar contraseña'),
            body: Container(),
            onTap: () =>
                _whenIdle(context, ref, () => showChangePasswordDialog(context)),
          ),
          PaneItem(
            title: const Text('Agregar perfil'),
            icon: const Icon(FluentIcons.add),
            body: Container(),
            onTap: () =>
                _whenIdle(context, ref, () => showCreateProfileDialog(context)),
          ),
        ],
        onChanged: (value) {
          if (value >= profiles.length) return;
          _whenIdle(context, ref, () {
            ref.read(quotaControllerProvider.notifier).reset();
            ref
                .read(selectedProfileIdProvider.notifier)
                .select(profiles[value].id);
          });
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.globe,
            size: 35,
          ),
          SizedBox(
            height: 16,
          ),
          Text(
            textAlign: TextAlign.center,
            'Ningún perfil proxy creado todavía',
            style: TextStyle(
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(
            height: 16,
          ),
          _CreateFirstProfileButton(),
        ],
      ),
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
