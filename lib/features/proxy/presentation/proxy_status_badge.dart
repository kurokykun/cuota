import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Colored dot and short description of the proxy state.
class ProxyStatusBadge extends StatelessWidget {
  const ProxyStatusBadge({super.key, required this.status});

  final ProxyStatus status;

  @override
  Widget build(BuildContext context) {
    final profile = status.profile;
    final (color, label) = switch (status.phase) {
      ProxyPhase.stopped => (Colors.grey[100], 'Detenido'),
      ProxyPhase.starting => (Colors.orange, 'Iniciando…'),
      ProxyPhase.stopping => (Colors.orange, 'Deteniendo…'),
      ProxyPhase.running => (
          Colors.green.lighter,
          'Activo en ${profile?.localAddress}:${profile?.localPort}',
        ),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.caption,
          ),
        ),
      ],
    );
  }
}
