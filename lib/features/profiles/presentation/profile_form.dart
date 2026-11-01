import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_validators.dart';
import 'package:cuota/features/profiles/presentation/profile_colors.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:cuota/features/proxy/presentation/proxy_status_badge.dart';
import 'package:cuota/features/quota/presentation/quota_card.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();

  // Filled once: later rebuilds must not discard what the user is typing.
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _upstreamHost;
  late final TextEditingController _upstreamPort;
  late final TextEditingController _localAddress;
  late final TextEditingController _localPort;
  late final TextEditingController _domain;
  late final TextEditingController _exclusions;

  Profile? get _stored {
    final profiles = ref.read(profilesControllerProvider).value?.profiles;
    for (final profile in profiles ?? const <Profile>[]) {
      if (profile.id == widget.profileId) return profile;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final profile = _stored;
    _username = TextEditingController(text: profile?.username);
    _password = TextEditingController(text: profile?.password);
    _upstreamHost = TextEditingController(text: profile?.upstreamHost);
    _upstreamPort = TextEditingController(text: profile?.upstreamPort);
    _localAddress = TextEditingController(text: profile?.localAddress);
    _localPort = TextEditingController(text: profile?.localPort);
    _domain = TextEditingController(text: profile?.domain);
    _exclusions = TextEditingController(text: profile?.noProxy.join('\n'));
  }

  @override
  void dispose() {
    for (final controller in [
      _username,
      _password,
      _upstreamHost,
      _upstreamPort,
      _localAddress,
      _localPort,
      _domain,
      _exclusions,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Profile _draft(Profile stored) => stored.copyWith(
        username: _username.text,
        password: _password.text,
        upstreamHost: _upstreamHost.text,
        upstreamPort: _upstreamPort.text,
        localAddress: _localAddress.text,
        localPort: _localPort.text,
        domain: _domain.text,
        noProxy: ProfileValidators.parseExclusions(_exclusions.text),
      );

  void _toggleProxy(ProxyStatus status) {
    final proxy = ref.read(proxyControllerProvider.notifier);
    if (status.phase == ProxyPhase.running) {
      proxy.stop();
    } else if (status.phase == ProxyPhase.stopped) {
      final stored = _stored;
      if (stored != null) proxy.start(_draft(stored));
    }
  }

  Future<void> _pickColor() async {
    await showDialog<void>(
      barrierDismissible: true,
      context: context,
      builder: (dialogContext) => ContentDialog(
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
                  Navigator.of(dialogContext).pop();
                  try {
                    await ref
                        .read(profilesControllerProvider.notifier)
                        .setColor(widget.profileId, color);
                  } on Failure catch (failure) {
                    if (mounted) {
                      showMessage(context, failure.message,
                          severity: InfoBarSeverity.error);
                    }
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
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required bool enabled,
    required FormFieldValidator<String> validator,
    String? placeholder,
  }) {
    return InfoLabel(
      label: label,
      child: TextFormBox(
        enabled: enabled,
        controller: controller,
        placeholder: placeholder,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
      ),
    );
  }

  Widget _hostAndPort({
    required String hostLabel,
    required TextEditingController host,
    required FormFieldValidator<String> hostValidator,
    required TextEditingController port,
    required bool enabled,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _field(hostLabel, host,
              enabled: enabled, validator: hostValidator),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: _field('Puerto', port,
              enabled: enabled, validator: ProfileValidators.port),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(proxyControllerProvider);
    final profile = ref.watch(selectedProfileProvider);
    final color = (profile?.color ?? ProfileColor.teal).color;
    final enabled = !status.isBusy;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    name: profile?.name ?? '',
                    color: color,
                    status: status,
                    onPickColor: enabled ? _pickColor : null,
                  ),
                  const SizedBox(height: 16),
                  QuotaCard(accent: color),
                  const SizedBox(height: 16),
                  _field('Usuario', _username,
                      enabled: enabled,
                      placeholder: 'Su usuario de la UCI',
                      validator: ProfileValidators.username),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: 'Contraseña',
                    child: PasswordFormBox(
                      enabled: enabled,
                      controller: _password,
                      placeholder: 'Se guarda en el llavero del sistema',
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: ProfileValidators.password,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expander(
                    header: const Text('Servidor y red'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hostAndPort(
                          hostLabel: 'Servidor remoto',
                          host: _upstreamHost,
                          hostValidator: ProfileValidators.host,
                          port: _upstreamPort,
                          enabled: enabled,
                        ),
                        const SizedBox(height: 12),
                        _hostAndPort(
                          hostLabel: 'Dirección local',
                          host: _localAddress,
                          hostValidator: ProfileValidators.ipv4,
                          port: _localPort,
                          enabled: enabled,
                        ),
                        const SizedBox(height: 12),
                        _field('Dominio', _domain,
                            enabled: enabled,
                            validator: ProfileValidators.domain),
                        const SizedBox(height: 12),
                        InfoLabel(
                          label: 'Exclusiones (una por línea)',
                          child: TextFormBox(
                            enabled: enabled,
                            controller: _exclusions,
                            keyboardType: TextInputType.multiline,
                            minLines: 3,
                            maxLines: 5,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) => ProfileValidators.exclusions(
                                ProfileValidators.parseExclusions(value!)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: _ProxyButton(
                status: status,
                color: color,
                onPressed: () => _toggleProxy(status),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.color,
    required this.status,
    required this.onPickColor,
  });

  final String name;
  final Color color;
  final ProxyStatus status;
  final VoidCallback? onPickColor;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Row(
      children: [
        Tooltip(
          message: 'Cambiar color',
          child: GestureDetector(
            onTap: onPickColor,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(FluentIcons.globe, size: 24),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ProxyStatusBadge(status: status),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProxyButton extends StatelessWidget {
  const _ProxyButton({
    required this.status,
    required this.color,
    required this.onPressed,
  });

  final ProxyStatus status;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    Widget content(IconData? icon, String label, Color? foreground) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon == null)
              const SizedBox.square(
                dimension: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            else
              Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: foreground)),
          ],
        );

    switch (status.phase) {
      case ProxyPhase.starting:
        return Button(onPressed: null, child: content(null, 'Iniciando…', null));
      case ProxyPhase.stopping:
        return Button(onPressed: null, child: content(null, 'Deteniendo…', null));
      case ProxyPhase.running:
        return Button(
          onPressed: onPressed,
          child: content(FluentIcons.stop, 'Detener proxy', null),
        );
      case ProxyPhase.stopped:
        final foreground =
            color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
        return FilledButton(
          onPressed: onPressed,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(color),
          ),
          child: content(FluentIcons.play, 'Iniciar proxy', foreground),
        );
    }
  }
}
