import 'dart:math' as math;

import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_validators.dart';
import 'package:cuota/features/profiles/presentation/profile_colors.dart';
import 'package:cuota/features/profiles/presentation/profile_header.dart';
import 'package:cuota/features/profiles/presentation/profile_settings.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/presentation/power_orb.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:cuota/features/quota/domain/quota.dart';
import 'package:cuota/features/quota/presentation/quota_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everything needed day to day, without scrolling: the switch, the quota and
/// a summary of how the profile is configured.
class ProfileHome extends ConsumerWidget {
  const ProfileHome({
    super.key,
    required this.profileId,
    required this.onOpenSettings,
  });

  final String profileId;
  final ValueChanged<SettingsSection> onOpenSettings;

  void _toggle(WidgetRef ref, Profile profile, ProxyStatus status) {
    final proxy = ref.read(proxyControllerProvider.notifier);
    if (status.phase == ProxyPhase.running) {
      proxy.stop();
      return;
    }
    final missing = ProfileValidators.username(profile.username) ??
        ProfileValidators.password(profile.password);
    if (missing != null) {
      ref
          .read(messagesProvider.notifier)
          .show(missing, severity: InfoBarSeverity.warning);
      onOpenSettings(SettingsSection.account);
      return;
    }
    proxy.start(profile);
  }

  /// The ring warns as the quota runs out, whatever the profile color is.
  Color _ringColor(double fraction, Color accent) {
    if (fraction >= 0.9) return Colors.red;
    if (fraction >= 0.75) return Colors.orange;
    return accent;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles =
        ref.watch(profilesControllerProvider).value?.profiles ?? const [];
    final profile = profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return const SizedBox.shrink();

    final status = ref.watch(proxyControllerProvider);
    final quota = ref.watch(quotaControllerProvider);
    final accent = profile.color.color;
    final fraction = quota.quota?.usedFraction ?? 0;
    final transitioning = status.phase == ProxyPhase.starting ||
        status.phase == ProxyPhase.stopping;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileHeader(profile: profile),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The orb uses the room left by the texts, within reason.
                final orbSize = math.min(
                  constraints.maxWidth * 0.78,
                  constraints.maxHeight - 110,
                ).clamp(120.0, 300.0);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    PowerOrb(
                      key: const ValueKey('power-orb'),
                      size: orbSize,
                      phase: status.phase,
                      accent: accent,
                      ringColor: _ringColor(fraction, accent),
                      fraction: fraction,
                      onPressed: transitioning
                          ? null
                          : () => _toggle(ref, profile, status),
                    ),
                    _StatusText(status: status, accent: accent),
                  ],
                );
              },
            ),
          ),
          _QuotaCard(
            state: quota,
            running: status.phase == ProxyPhase.running,
            color: _ringColor(fraction, accent),
          ),
          const SizedBox(height: 8),
          _Summary(profile: profile, onOpenSettings: onOpenSettings),
          const MessageStrip(padding: EdgeInsets.only(top: 8)),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.status, required this.accent});

  final ProxyStatus status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    final profile = status.profile;
    final (title, detail) = switch (status.phase) {
      ProxyPhase.stopped => ('Detenido', 'Pulse para iniciar'),
      ProxyPhase.starting => ('Iniciando…', ''),
      ProxyPhase.stopping => ('Deteniendo…', ''),
      ProxyPhase.running => (
          'Conectado',
          profile?.gateway ?? false
              ? 'Compartido en el puerto ${profile?.localPort}'
              : '${profile?.localAddress}:${profile?.localPort}',
        ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Column(
        key: ValueKey(title),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: typography.subtitle?.copyWith(
              shadows: status.phase == ProxyPhase.running
                  ? [Shadow(color: accent, blurRadius: 18)]
                  : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(detail, style: typography.caption),
        ],
      ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({
    required this.state,
    required this.running,
    required this.color,
  });

  final QuotaState state;
  final bool running;
  final Color color;

  String _describe(Quota? quota) {
    if (quota != null) {
      return '${quota.used.toInt()} de ${quota.total.toInt()} · '
          '${(quota.usedFraction * 100).round()} %';
    }
    if (!running) return 'Sin datos';
    return state.error == null ? 'Consultando…' : 'No disponible';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final error = state.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Cuota', style: theme.typography.body),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _describe(state.quota),
                  textAlign: TextAlign.end,
                  style: theme.typography.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: state.quota?.usedFraction ?? 0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                        color: theme.resources.controlStrokeColorDefault),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: ColoredBox(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(FluentIcons.warning,
                            size: 12, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            error,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.profile, required this.onOpenSettings});

  final Profile profile;
  final ValueChanged<SettingsSection> onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hosts = profile.allowedHosts.length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _SummaryRow(
            key: const ValueKey('row-account'),
            icon: FluentIcons.contact,
            label: 'Cuenta',
            value: profile.username.isEmpty
                ? 'Sin configurar'
                : profile.username,
            highlight: profile.username.isEmpty ? Colors.orange : null,
            onTap: () => onOpenSettings(SettingsSection.account),
          ),
          _SummaryRow(
            key: const ValueKey('row-server'),
            icon: FluentIcons.globe,
            label: 'Servidor',
            value: '${profile.upstreamHost}:${profile.upstreamPort}',
            onTap: () => onOpenSettings(SettingsSection.server),
          ),
          _SummaryRow(
            key: const ValueKey('row-sharing'),
            icon: FluentIcons.share,
            label: 'Compartir',
            value: profile.gateway
                ? 'Activado · $hosts ${hosts == 1 ? 'equipo' : 'equipos'}'
                : 'Desactivado',
            highlight: profile.gateway ? profile.color.color : null,
            glowing: profile.gateway,
            onTap: () => onOpenSettings(SettingsSection.sharing),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatefulWidget {
  const _SummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.highlight,
    this.glowing = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// Color of the value when it deserves attention.
  final Color? highlight;
  final bool glowing;

  @override
  State<_SummaryRow> createState() => _SummaryRowState();
}

class _SummaryRowState extends State<_SummaryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final highlight = widget.highlight;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: _hovered
              ? theme.resources.subtleFillColorSecondary
              : const Color(0x00000000),
          child: Row(
            children: [
              Icon(widget.icon, size: 14),
              const SizedBox(width: 10),
              Text(widget.label, style: theme.typography.body),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.glowing) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: highlight,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: highlight ?? const Color(0x00000000),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption
                            ?.copyWith(color: highlight),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(FluentIcons.chevron_right, size: 10),
            ],
          ),
        ),
      ),
    );
  }
}
