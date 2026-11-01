import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppMessage {
  const AppMessage(this.text, this.severity);

  final String text;
  final InfoBarSeverity severity;
}

final messagesProvider =
    NotifierProvider<MessagesController, AppMessage?>(MessagesController.new);

/// The message shown in the [AppBanner]. Only one at a time, the newest wins.
class MessagesController extends Notifier<AppMessage?> {
  static const _autoDismissAfter = Duration(seconds: 5);

  Timer? _timer;

  @override
  AppMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Errors and warnings stay until dismissed, they may need to be read twice.
  void show(String text, {InfoBarSeverity severity = InfoBarSeverity.info}) {
    _timer?.cancel();
    state = AppMessage(text, severity);
    if (severity == InfoBarSeverity.info ||
        severity == InfoBarSeverity.success) {
      _timer = Timer(_autoDismissAfter, dismiss);
    }
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }
}

/// Message next to the action that caused it. It only takes space from the
/// scrollable content, so the rest of the screen stays in place.
class MessageStrip extends ConsumerWidget {
  const MessageStrip({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(messagesProvider);
    final theme = FluentTheme.of(context);
    return AnimatedSize(
      duration: theme.fastAnimationDuration,
      alignment: Alignment.bottomCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: padding,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _SeverityIcon(message.severity),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(message.text,
                          style: theme.typography.caption),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.clear, size: 10),
                      onPressed: ref.read(messagesProvider.notifier).dismiss,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SeverityIcon extends StatelessWidget {
  const _SeverityIcon(this.severity);

  final InfoBarSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (severity) {
      InfoBarSeverity.error => (FluentIcons.error_badge, Colors.red.lighter),
      InfoBarSeverity.warning => (FluentIcons.warning, Colors.orange),
      InfoBarSeverity.success => (FluentIcons.completed, Colors.green.lighter),
      _ => (FluentIcons.info, Colors.blue.lighter),
    };
    return Icon(icon, size: 14, color: color);
  }
}
