import 'package:fluent_ui/fluent_ui.dart';

/// Editable list of short values shown as removable chips. Values are added
/// with Enter or the add button; pasting several at once also works.
class ChipListField extends StatefulWidget {
  const ChipListField({
    super.key,
    required this.values,
    required this.onChanged,
    required this.validator,
    required this.placeholder,
    required this.enabled,
    required this.splitter,
    this.suggestions = const [],
    this.inputKey,
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  /// Returns the error message of a single value, or null when valid.
  final String? Function(String value) validator;

  /// Turns the typed text into the values to add.
  final List<String> Function(String text) splitter;
  final String placeholder;
  final bool enabled;

  /// Values offered for adding with one click.
  final List<String> suggestions;
  final Key? inputKey;

  @override
  State<ChipListField> createState() => _ChipListFieldState();
}

class _ChipListFieldState extends State<ChipListField> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addAll(Iterable<String> entries) {
    final next = List.of(widget.values);
    for (final entry in entries) {
      final error = widget.validator(entry);
      if (error != null) {
        // Keep the text so a typo can be fixed instead of retyped.
        setState(() => _error = error);
        return;
      }
      if (!next.contains(entry)) next.add(entry);
    }
    setState(() => _error = null);
    _input.clear();
    if (next.length != widget.values.length) widget.onChanged(next);
  }

  void _submit() {
    _addAll(widget.splitter(_input.text));
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final suggestions =
        widget.suggestions.where((s) => !widget.values.contains(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextBox(
          key: widget.inputKey,
          controller: _input,
          focusNode: _focus,
          enabled: widget.enabled,
          placeholder: widget.placeholder,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          suffix: IconButton(
            icon: const Icon(FluentIcons.add, size: 12),
            onPressed: widget.enabled ? _submit : null,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _error!,
            style: theme.typography.caption?.copyWith(color: Colors.red.lighter),
          ),
        ],
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in widget.values)
                _ValueChip(
                  label: value,
                  onRemoved: widget.enabled
                      ? () => widget.onChanged(
                          widget.values.where((v) => v != value).toList())
                      : null,
                ),
            ],
          ),
        ],
        if (suggestions.isNotEmpty && widget.enabled) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Sugerencias:', style: theme.typography.caption),
              for (final suggestion in suggestions)
                HyperlinkButton(
                  onPressed: () => _addAll([suggestion]),
                  child: Text('+ $suggestion'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.onRemoved});

  final String label;
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 10, end: 2),
      decoration: BoxDecoration(
        color: theme.resources.controlFillColorSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.typography.caption),
          SizedBox.square(
            dimension: 26,
            child: IconButton(
              icon: const Icon(FluentIcons.clear, size: 8),
              onPressed: onRemoved,
            ),
          ),
        ],
      ),
    );
  }
}
