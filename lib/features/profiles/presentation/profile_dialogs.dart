import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_validators.dart';
import 'package:cuota/features/profiles/presentation/profile_colors.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showCreateProfileDialog(BuildContext context) => showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) => const _CreateProfileDialog(),
    );

class _CreateProfileDialog extends ConsumerStatefulWidget {
  const _CreateProfileDialog();

  @override
  ConsumerState<_CreateProfileDialog> createState() =>
      _CreateProfileDialogState();
}

class _CreateProfileDialogState extends ConsumerState<_CreateProfileDialog> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final profile = await ref
          .read(profilesControllerProvider.notifier)
          .create(_name.text);
      ref.read(selectedProfileIdProvider.notifier).select(profile.id);
      if (mounted) Navigator.pop(context);
    } on Failure catch (failure) {
      setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      actions: [
        Button(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Crear'),
        )
      ],
      constraints: const BoxConstraints(maxHeight: 280, maxWidth: 340),
      title: const Text('Nuevo perfil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoLabel(
            label: 'Nombre',
            child: TextBox(
              autofocus: true,
              controller: _name,
              placeholder: 'Por ejemplo: Residencia',
              maxLength: ProfileValidators.maxNameLength,
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red.lighter)),
          ],
        ],
      ),
    );
  }
}

Future<void> showDeleteProfileDialog(BuildContext context, Profile profile) =>
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (dialogContext, ref, _) => ContentDialog(
          actions: [
            Button(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.red),
              ),
              onPressed: () async {
                try {
                  await ref
                      .read(profilesControllerProvider.notifier)
                      .delete(profile.id);
                } on Failure catch (failure) {
                  ref.read(messagesProvider.notifier).show(failure.message,
                      severity: InfoBarSeverity.error);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Eliminar',
                  style: TextStyle(color: Color(0xFFFFFFFF))),
            )
          ],
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 340),
          title: const Text('Eliminar perfil'),
          content: Text(
              'Se eliminará "${profile.name}" y su contraseña guardada. '
              'Esta acción no se puede deshacer.'),
        ),
      ),
    );

Future<void> showProfileColorDialog(BuildContext context, String profileId) =>
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (dialogContext, ref, _) => ContentDialog(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
          title: const Text('Color del perfil'),
          content: Wrap(
            runSpacing: 10.0,
            spacing: 8.0,
            children: [
              for (final color in pickableProfileColors)
                Button(
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.all(4.0),
                    ),
                  ),
                  onPressed: () async {
                    final messages = ref.read(messagesProvider.notifier);
                    final profiles =
                        ref.read(profilesControllerProvider.notifier);
                    Navigator.of(dialogContext).pop();
                    try {
                      await profiles.setColor(profileId, color);
                    } on Failure catch (failure) {
                      messages.show(failure.message,
                          severity: InfoBarSeverity.error);
                    }
                  },
                  child: Container(
                    height: 40.0,
                    width: 40.0,
                    decoration: BoxDecoration(
                      color: color.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
