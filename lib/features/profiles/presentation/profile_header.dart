import 'package:cuota/core/presentation/action_sheet.dart';
import 'package:cuota/features/account/presentation/account_providers.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/presentation/profile_colors.dart';
import 'package:cuota/features/profiles/presentation/profile_dialogs.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:cuota/features/quota/presentation/quota_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The icon changes the color of the profile and the name switches to another
/// one. What is rarely needed stays behind the menu button.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key, required this.profile});

  final Profile profile;

  void _openProfiles(BuildContext context, WidgetRef ref) {
    final profiles =
        ref.read(profilesControllerProvider).value?.profiles ?? const [];
    showActionSheet(
      context,
      title: 'Perfiles',
      actions: [
        for (final other in profiles)
          SheetAction(
            label: other.name,
            leading: _ColorDot(other.color.color),
            selected: other.id == profile.id,
            onSelected: () {
              ref.read(quotaControllerProvider.notifier).reset();
              ref.read(selectedProfileIdProvider.notifier).select(other.id);
            },
          ),
        SheetAction(
          label: 'Nuevo perfil',
          leading: const Icon(FluentIcons.add, size: 14),
          separated: true,
          onSelected: () => showCreateProfileDialog(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final busy = ref.watch(proxyControllerProvider).isBusy;
    return Row(
      children: [
        Tooltip(
          message: 'Cambiar color',
          child: HoverButton(
            key: const ValueKey('profile-color'),
            semanticLabel: 'Cambiar color',
            onPressed:
                busy ? null : () => showProfileColorDialog(context, profile.id),
            builder: (context, states) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: profile.color.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(FluentIcons.globe, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: HoverButton(
              key: const ValueKey('profile-selector'),
              semanticLabel: 'Cambiar de perfil',
              onPressed: busy ? null : () => _openProfiles(context, ref),
              builder: (context, states) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: states.isHovered
                      ? theme.resources.subtleFillColorSecondary
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Profiles cannot be switched while the proxy is running.
                    if (!busy) ...[
                      const SizedBox(width: 8),
                      const Icon(FluentIcons.chevron_down, size: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ProfileMenuButton(profile: profile),
      ],
    );
  }
}

/// Actions on the [profile], or only the ones on the account without one.
class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key, this.profile});

  final Profile? profile;

  void _open(BuildContext context, WidgetRef ref) {
    final profile = this.profile;
    showActionSheet(
      context,
      title: 'Opciones',
      actions: [
        SheetAction(
          label: 'Cambiar contraseña',
          leading: const Icon(FluentIcons.lock, size: 14),
          onSelected: ref.read(changePasswordOpenProvider.notifier).open,
        ),
        if (profile != null)
          SheetAction(
            label: 'Eliminar perfil',
            leading:
                Icon(FluentIcons.delete, size: 14, color: Colors.red.lighter),
            destructive: true,
            separated: true,
            onSelected: () => showDeleteProfileDialog(context, profile),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(proxyControllerProvider).isBusy;
    return IconButton(
      key: const ValueKey('profile-menu'),
      icon: const Icon(FluentIcons.more, size: 16),
      onPressed: busy ? null : () => _open(context, ref),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
