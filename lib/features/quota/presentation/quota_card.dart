import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:cuota/features/quota/presentation/quota_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuotaCard extends ConsumerWidget {
  const QuotaCard({super.key, required this.accent});

  final Color accent;

  /// The bar warns as the quota runs out, whatever the profile color is.
  Color _barColor(double fraction) {
    if (fraction >= 0.9) return Colors.red;
    if (fraction >= 0.75) return Colors.orange;
    return accent;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quotaControllerProvider);
    final running =
        ref.watch(proxyControllerProvider).phase == ProxyPhase.running;
    final typography = FluentTheme.of(context).typography;
    final quota = state.quota;

    return Card(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cuota utilizada', style: typography.caption),
              if (quota != null)
                Text(
                  '${(quota.usedFraction * 100).round()} %',
                  style: typography.caption,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (quota == null)
            Text(
              running && state.error == null
                  ? 'Consultando…'
                  : 'Inicie el proxy para consultar su cuota',
              style: typography.body,
            )
          else
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${quota.used.toInt()}',
                  style: typography.title,
                ),
                TextSpan(
                  text: ' de ${quota.total.toInt()}',
                  style: typography.body,
                ),
              ]),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ProgressBar(
              value: (quota?.usedFraction ?? 0) * 100,
              activeColor: _barColor(quota?.usedFraction ?? 0),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(FluentIcons.warning, size: 14, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(state.error!, style: typography.caption),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
