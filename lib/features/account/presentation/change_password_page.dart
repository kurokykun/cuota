import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/account/domain/account.dart';
import 'package:cuota/features/account/presentation/account_providers.dart';
import 'package:cuota/features/profiles/presentation/profile_colors.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(
    text: ref.read(selectedProfileProvider)?.username,
  );
  final _current = TextEditingController();
  final _replacement = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The list of requirements follows what is being typed.
    _replacement.addListener(() => setState(() {}));
  }

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
    ref.read(changePasswordOpenProvider.notifier).close();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messages = ref.read(messagesProvider.notifier);
    final page = ref.read(changePasswordOpenProvider.notifier);
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
    TextEditingController controller,
    FormFieldValidator<String> validator,
  ) {
    return InfoLabel(
      label: label,
      child: PasswordFormBox(
        controller: controller,
        enabled: !_busy,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    final accent = ref.watch(selectedProfileProvider)?.color.color;

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
                    style: typography.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoLabel(
                        label: 'Usuario',
                        child: TextFormBox(
                          controller: _username,
                          enabled: !_busy,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) => value!.isEmpty
                              ? 'El usuario es obligatorio'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _password(
                        'Contraseña actual',
                        _current,
                        (value) => value!.isEmpty
                            ? 'La contraseña es obligatoria'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _password(
                        'Contraseña nueva',
                        _replacement,
                        (value) => PasswordPolicy.isStrong(value!)
                            ? null
                            : 'No cumple los requisitos',
                      ),
                      const SizedBox(height: 8),
                      for (final requirement in PasswordPolicy.requirements)
                        _Requirement(
                          label: requirement.label,
                          met: requirement.isMet(_replacement.text),
                        ),
                      const SizedBox(height: 12),
                      _password(
                        'Confirmar contraseña nueva',
                        _confirmation,
                        (value) => value == _replacement.text
                            ? null
                            : 'Las contraseñas no coinciden',
                      ),
                    ],
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
                child: FilledButton(
                  key: const ValueKey('password-submit'),
                  onPressed: _busy ? null : _submit,
                  style: accent == null
                      ? null
                      : ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.isDisabled ? null : accent,
                          ),
                        ),
                  child: Text(
                    _busy ? 'Cambiando…' : 'Cambiar contraseña',
                    style: accent == null || _busy
                        ? null
                        : TextStyle(
                            color: accent.computeLuminance() > 0.45
                                ? Colors.black
                                : Colors.white,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final caption = FluentTheme.of(context).typography.caption;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              met ? FluentIcons.completed_solid : FluentIcons.circle_ring,
              key: ValueKey(met),
              size: 12,
              color: met ? Colors.green.lighter : caption?.color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: caption)),
        ],
      ),
    );
  }
}
