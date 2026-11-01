import 'package:cuota/features/profiles/presentation/profile_home.dart';
import 'package:cuota/features/profiles/presentation/profile_settings.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Using a profile and configuring it are separate views of the same page.
class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  SettingsSection? _section;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(newProfileIdProvider) != widget.profileId) return;
    _isNew = true;
    _section = SettingsSection.account;
    // Providers cannot change while the tree is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(newProfileIdProvider.notifier).set(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    // The Android back button leaves the settings, not the app.
    return PopScope(
      canPop: section == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _section = null);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final fromRight = child.key == const ValueKey('settings');
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: Offset(fromRight ? 0.08 : -0.08, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: section == null
            ? ProfileHome(
                key: const ValueKey('home'),
                profileId: widget.profileId,
                onOpenSettings: (section) => setState(() => _section = section),
              )
            : ProfileSettings(
                key: const ValueKey('settings'),
                profileId: widget.profileId,
                initialSection: section,
                selectName: _isNew,
                onClose: () => setState(() => _section = null),
              ),
      ),
    );
  }
}
