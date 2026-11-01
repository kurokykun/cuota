import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/presentation/app_page.dart';
import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/account/domain/account.dart';
import 'package:cuota/features/account/presentation/account_providers.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  late final _username = TextEditingController(
    text: ref.read(selectedProfileProvider)?.username,
  );
  final _current = TextEditingController();
  final _replacement = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;

  bool get _matches =>
      _confirmation.text.isNotEmpty && _confirmation.text == _replacement.text;

  /// The action becomes available when there is nothing left to correct, so
  /// the form does not have to scold about fields still being typed.
  bool get _canSubmit =>
      !_busy &&
      _username.text.isNotEmpty &&
      _current.text.isNotEmpty &&
      PasswordPolicy.isStrong(_replacement.text) &&
      _matches;

  void _refresh(String _) => setState(() {});

  @override
  void dispose() {
    _username.dispose();
    _current.dispose();
    _replacement.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _close() {
    ref.read(messagesProvider.notifier).dismiss();
    ref.read(appPageProvider.notifier).close();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final messages = ref.read(messagesProvider.notifier);
    final page = ref.read(appPageProvider.notifier);
    messages.dismiss();
    setState(() => _busy = true);
    try {
      await ref.read(changePasswordProvider)(PasswordChange(
        username: _username.text,
        current: _current.text,
        replacement: _replacement.text,
        confirmation: _confirmation.text,
      ));
      page.close();
      messages.show(
        'Contraseña cambiada. Actualícela también en la cuenta de sus perfiles',
        severity: InfoBarSeverity.success,
      );
    } on Failure catch (failure) {
      messages.show(failure.message, severity: InfoBarSeverity.error);
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _password(
    String label,
    TextEditingController controller, {
    VoidCallback? onDone,
  }) {
    return InfoLabel(
      label: label,
      child: PasswordBox(
        controller: controller,
        enabled: !_busy,
        revealMode: PasswordRevealMode.peekAlways,
        onChanged: _refresh,
        onSubmitted: (_) => onDone?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _close();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('password-back'),
                  icon: const Icon(FluentIcons.back, size: 14),
                  onPressed: _busy ? null : _close,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cambiar contraseña',
                    style: theme.typography.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      children: [
                        InfoLabel(
                          label: 'Usuario',
                          child: TextBox(
                            controller: _username,
                            enabled: !_busy,
                            onChanged: _refresh,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _password('Contraseña actual', _current),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      children: [
                        _password('Contraseña nueva', _replacement),
                        const SizedBox(height: 10),
                        _StrengthBar(value: _replacement.text),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final requirement
                                in PasswordPolicy.requirements)
                              _RequirementChip(
                                label: requirement.label,
                                met: requirement.isMet(_replacement.text),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _password(
                          'Repetir contraseña nueva',
                          _confirmation,
                          onDone: _submit,
                        ),
                        _MatchHint(
                          visible: _confirmation.text.isNotEmpty,
                          matches: _matches,
                        ),
                      ],
                    ),
                  ],
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
                child: FilledButton(
                  key: const ValueKey('password-submit'),
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(_busy ? 'Cambiando…' : 'Cambiar contraseña'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// One segment per requirement, so progress is readable at a glance.
class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final requirements = PasswordPolicy.requirements;
    final met = requirements.where((r) => r.isMet(value)).length;
    final color = switch (met) {
      <= 2 => Colors.red.lighter,
      < 5 => Colors.orange,
      _ => Colors.green.lighter,
    };
    return Row(
      children: [
        for (var index = 0; index < requirements.length; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: index < met
                    ? color
                    : theme.resources.controlStrokeColorDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RequirementChip extends StatelessWidget {
  const _RequirementChip({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final green = Colors.green.lighter;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? green.withValues(alpha: 0.16)
            : theme.resources.controlFillColorSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (met) ...[
            Icon(FluentIcons.accept, size: 10, color: green),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.typography.caption?.copyWith(
              color: met ? green : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHint extends StatelessWidget {
  const _MatchHint({required this.visible, required this.matches});

  final bool visible;
  final bool matches;

  @override
  Widget build(BuildContext context) {
    final color = matches ? Colors.green.lighter : Colors.orange;
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    matches ? FluentIcons.accept : FluentIcons.warning,
                    size: 11,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    matches ? 'Coinciden' : 'Todavía no coinciden',
                    style: FluentTheme.of(context)
                        .typography
                        .caption
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ),
    );
  }
}
