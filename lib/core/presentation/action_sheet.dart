import 'package:fluent_ui/fluent_ui.dart';

class SheetAction {
  const SheetAction({
    required this.label,
    required this.leading,
    required this.onSelected,
    this.selected = false,
    this.destructive = false,
    this.separated = false,
  });

  final String label;
  final Widget leading;
  final VoidCallback onSelected;

  /// Marks the current option of a list.
  final bool selected;
  final bool destructive;

  /// Draws a divider above, to set this action apart from the previous ones.
  final bool separated;
}

/// Panel that slides up from the bottom. Tapping outside or dragging it down
/// closes it. The chosen action runs once the panel is gone, so it can open a
/// dialog of its own.
Future<void> showActionSheet(
  BuildContext context, {
  required String title,
  required List<SheetAction> actions,
}) async {
  final chosen = await showGeneralDialog<SheetAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: const Color(0x80000000),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => _ActionSheet(title: title, actions: actions),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      ),
      child: child,
    ),
  );
  chosen?.onSelected();
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.title, required this.actions});

  static const _dismissVelocity = 300.0;

  final String title;
  final List<SheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > _dismissVelocity) {
            Navigator.pop(context);
          }
        },
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          decoration: BoxDecoration(
            color: theme.menuColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.resources.controlStrongFillColorDefault,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(title, style: theme.typography.caption),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final action in actions) ...[
                          if (action.separated)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Divider(),
                            ),
                          _ActionRow(action),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow(this.action);

  final SheetAction action;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = action.destructive ? Colors.red.lighter : null;
    return HoverButton(
      semanticLabel: action.label,
      onPressed: () => Navigator.pop(context, action),
      builder: (context, states) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        // Comfortable as a touch target, above the usual 48 points.
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: states.isHovered || states.isPressed
            ? theme.resources.subtleFillColorSecondary
            : const Color(0x00000000),
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: action.leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body?.copyWith(color: color),
              ),
            ),
            if (action.selected) const Icon(FluentIcons.accept, size: 14),
          ],
        ),
      ),
    );
  }
}
