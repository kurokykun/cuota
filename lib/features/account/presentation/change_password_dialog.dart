import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/account/domain/account.dart';
import 'package:cuota/features/account/presentation/account_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showChangePasswordDialog(BuildContext context) => showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(pageContext: context),
    );

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({required this.pageContext});

  /// Stays valid to report the result once the dialog is closed.
  final BuildContext pageContext;

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _current = TextEditingController();
  final _replacement = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _current.dispose();
    _replacement.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(changePasswordProvider)(PasswordChange(
        username: _username.text,
        current: _current.text,
        replacement: _replacement.text,
        confirmation: _confirmation.text,
      ));
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.pageContext.mounted) {
        showMessage(
            widget.pageContext, 'Contraseña cambiada satisfactoriamente',
            severity: InfoBarSeverity.success);
      }
    } on Failure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      }
    }
  }

  Widget _password(
    String label,
    TextEditingController controller,
    FormFieldValidator<String> validator,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InfoLabel(
        label: label,
        child: PasswordFormBox(
          controller: controller,
          enabled: !_busy,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = FluentTheme.of(context).typography.caption;
    return ContentDialog(
      actions: [
        Button(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Cambiando…' : 'Cambiar'),
        )
      ],
      constraints: const BoxConstraints(maxHeight: 600, maxWidth: 360),
      title: const Text('Cambiar contraseña'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoLabel(
                label: 'Usuario',
                child: TextFormBox(
                  controller: _username,
                  enabled: !_busy,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) =>
                      value!.isEmpty ? 'El usuario es obligatorio' : null,
                ),
              ),
              _password(
                'Contraseña actual',
                _current,
                (value) =>
                    value!.isEmpty ? 'La contraseña es obligatoria' : null,
              ),
              _password(
                'Contraseña nueva',
                _replacement,
                (value) => PasswordPolicy.isStrong(value!)
                    ? null
                    : 'No cumple los requisitos',
              ),
              const SizedBox(height: 4),
              Text(PasswordPolicy.description, style: caption),
              _password(
                'Confirmar contraseña nueva',
                _confirmation,
                (value) => value == _replacement.text
                    ? null
                    : 'Las contraseñas no coinciden',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.lighter, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
