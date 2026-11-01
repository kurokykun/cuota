import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/presentation/app_page.dart';
import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/logs/domain/log_entry.dart';
import 'package:cuota/features/logs/presentation/log_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogsPage extends ConsumerWidget {
  const LogsPage({super.key});

  void _close(WidgetRef ref) {
    ref.read(messagesProvider.notifier).dismiss();
    ref.read(appPageProvider.notifier).close();
  }

  Future<void> _export(WidgetRef ref) async {
    final messages = ref.read(messagesProvider.notifier);
    final logs = ref.read(logControllerProvider.notifier);
    try {
      final path = await ref
          .read(logExporterProvider)
          .save(logFileName(DateTime.now()), logs.export());
      // The path has to stay long enough to be read and looked for.
      messages.show('Guardado en $path', severity: InfoBarSeverity.warning);
    } on Failure catch (failure) {
      messages.show(failure.message, severity: InfoBarSeverity.error);
    }
  }

  Future<void> _copy(WidgetRef ref) async {
    final messages = ref.read(messagesProvider.notifier);
    await Clipboard.setData(
      ClipboardData(text: ref.read(logControllerProvider.notifier).export()),
    );
    messages.show('Registro copiado');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final entries = ref.watch(logControllerProvider);
    final empty = entries.isEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(ref);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('logs-back'),
                  icon: const Icon(FluentIcons.back, size: 14),
                  onPressed: () => _close(ref),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Registro',
                    style: theme.typography.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Tooltip(
                  message: 'Vaciar registro',
                  child: IconButton(
                    key: const ValueKey('logs-clear'),
                    icon: const Icon(FluentIcons.delete, size: 14),
                    onPressed: empty
                        ? null
                        : ref.read(logControllerProvider.notifier).clear,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: empty
                      ? const _EmptyLog()
                      // Reversed, so the newest line stays in view on its own.
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: entries.length,
                          itemBuilder: (context, index) => _LogLine(
                            entries[entries.length - 1 - index],
                          ),
                        ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: MessageStrip(padding: EdgeInsets.only(top: 8)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: SizedBox(
                height: 40,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Button(
                        key: const ValueKey('logs-copy'),
                        onPressed: empty ? null : () => _copy(ref),
                        child: const Center(child: Text('Copiar')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('logs-export'),
                        onPressed: empty ? null : () => _export(ref),
                        child: const Center(child: Text('Exportar .txt')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Aún no hay actividad. Lo que ocurra al iniciar el proxy aparecerá '
          'aquí.',
          textAlign: TextAlign.center,
          style: FluentTheme.of(context).typography.caption,
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine(this.entry);

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final caption = FluentTheme.of(context).typography.caption;
    final color = switch (entry.level) {
      LogLevel.error => Colors.red.lighter,
      LogLevel.warning => Colors.orange,
      LogLevel.info => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '${formatLogTime(entry.time)}  ',
            style: TextStyle(color: caption?.color?.withValues(alpha: 0.6)),
          ),
          TextSpan(
            text: entry.message,
            style: TextStyle(color: color),
          ),
        ]),
        style: caption?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}
