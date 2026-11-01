import 'dart:async';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/presentation/chip_list_field.dart';
import 'package:cuota/core/presentation/messages.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_validators.dart';
import 'package:cuota/features/profiles/presentation/profile_colors.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SettingsSection {
  account('Cuenta'),
  server('Servidor'),
  sharing('Compartir');

  const SettingsSection(this.label);

  final String label;
}

/// Edits a profile. Every change is saved on its own shortly after it is made.
class ProfileSettings extends ConsumerStatefulWidget {
  const ProfileSettings({
    super.key,
    required this.profileId,
    required this.initialSection,
    required this.onClose,
  });

  final String profileId;
  final SettingsSection initialSection;
  final VoidCallback onClose;

  @override
  ConsumerState<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends ConsumerState<ProfileSettings> {
  static const _saveDelay = Duration(milliseconds: 500);

  late SettingsSection _section = widget.initialSection;

  /// Name and color cannot change while this view is open.
  late final Profile _base;
  late final ProfilesController _profiles;
  late final MessagesController _messages;

  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _domain;
  late final TextEditingController _upstreamHost;
  late final TextEditingController _upstreamPort;
  late final TextEditingController _localAddress;
  late final TextEditingController _localPort;
  late List<String> _exclusions;
  late List<String> _allowedHosts;
  late bool _gateway;

  Timer? _saveTimer;
  bool _dirty = false;

  /// Latest values, readable after the controllers are disposed.
  late Profile _lastDraft = _base;

  List<TextEditingController> get _controllers => [
        _username,
        _password,
        _domain,
        _upstreamHost,
        _upstreamPort,
        _localAddress,
        _localPort,
      ];

  @override
  void initState() {
    super.initState();
    _profiles = ref.read(profilesControllerProvider.notifier);
    _messages = ref.read(messagesProvider.notifier);
    _base = ref
        .read(profilesControllerProvider)
        .requireValue
        .profiles
        .firstWhere((p) => p.id == widget.profileId);
    _username = TextEditingController(text: _base.username);
    _password = TextEditingController(text: _base.password);
    _domain = TextEditingController(text: _base.domain);
    _upstreamHost = TextEditingController(text: _base.upstreamHost);
    _upstreamPort = TextEditingController(text: _base.upstreamPort);
    _localAddress = TextEditingController(text: _base.localAddress);
    _localPort = TextEditingController(text: _base.localPort);
    _exclusions = _base.noProxy;
    _allowedHosts = _base.allowedHosts;
    _gateway = _base.gateway;
    for (final controller in _controllers) {
      controller.addListener(_scheduleSave);
    }
  }

  @override
  void dispose() {
    // The widget tree is locked here, the provider must change after it.
    if (_dirty) unawaited(Future(_saveNow));
    _saveTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Profile _draft() => _base.copyWith(
        username: _username.text,
        password: _password.text,
        domain: _domain.text,
        upstreamHost: _upstreamHost.text,
        upstreamPort: _upstreamPort.text,
        localAddress: _localAddress.text,
        localPort: _localPort.text,
        noProxy: _exclusions,
        gateway: _gateway,
        allowedHosts: _allowedHosts,
      );

  void _scheduleSave() {
    if (_draftUnchanged) return;
    _dirty = true;
    _lastDraft = _draft();
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _saveNow);
  }

  /// Listeners also fire for selection changes, which are not edits.
  bool get _draftUnchanged =>
      !_dirty &&
      _username.text == _base.username &&
      _password.text == _base.password &&
      _domain.text == _base.domain &&
      _upstreamHost.text == _base.upstreamHost &&
      _upstreamPort.text == _base.upstreamPort &&
      _localAddress.text == _base.localAddress &&
      _localPort.text == _base.localPort;

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    _dirty = false;
    final draft = _lastDraft;
    try {
      await _profiles.saveProfile(draft);
    } on Failure catch (failure) {
      _messages.show(failure.message, severity: InfoBarSeverity.error);
    }
  }

  void _changeList(VoidCallback change) {
    setState(change);
    _dirty = true;
    _lastDraft = _draft();
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _saveNow);
  }

  void _close() {
    if (_dirty) unawaited(_saveNow());
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(proxyControllerProvider);
    final enabled = !status.isBusy;
    final typography = FluentTheme.of(context).typography;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('settings-back'),
                icon: const Icon(FluentIcons.back, size: 14),
                onPressed: _close,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _base.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _SectionTabs(
              selected: _section,
              onSelected: (section) => setState(() => _section = section),
            ),
          ),
          const SizedBox(height: 16),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text('Detenga el proxy para editar estos datos',
                  style: typography.caption),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              // The default layout would center sections shorter than the view.
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: _section == SettingsSection.sharing && !_gateway
                  ? _SharingIntro(
                      key: const ValueKey('sharing-intro'),
                      accent: _base.color.color,
                      onActivate: enabled
                          ? () => _changeList(() => _gateway = true)
                          : null,
                    )
                  : SingleChildScrollView(
                      key: ValueKey(_section),
                      padding: const EdgeInsets.only(left: 8),
                      child: switch (_section) {
                        SettingsSection.account => _account(enabled),
                        SettingsSection.server => _server(enabled),
                        SettingsSection.sharing => _sharing(enabled),
                      },
                    ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: MessageStrip(padding: EdgeInsets.only(top: 8)),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    FormFieldValidator<String> validator, {
    required bool enabled,
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

  Widget _account(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field('Usuario', _username, ProfileValidators.username,
            enabled: enabled, placeholder: 'Su usuario de la UCI'),
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
        const SizedBox(height: 12),
        _field('Dominio', _domain, ProfileValidators.domain, enabled: enabled),
      ],
    );
  }

  Widget _hostAndPort(
    String label,
    TextEditingController host,
    FormFieldValidator<String> validator,
    TextEditingController port, {
    required bool enabled,
    bool? hostEnabled,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _field(label, host, validator, enabled: hostEnabled ?? enabled),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: _field('Puerto', port, ProfileValidators.port,
              enabled: enabled),
        ),
      ],
    );
  }

  Widget _server(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hostAndPort('Servidor remoto', _upstreamHost, ProfileValidators.host,
            _upstreamPort,
            enabled: enabled),
        const SizedBox(height: 12),
        _hostAndPort('Dirección local', _localAddress, ProfileValidators.ipv4,
            _localPort,
            enabled: enabled, hostEnabled: enabled && !_gateway),
        const SizedBox(height: 12),
        InfoLabel(
          label: 'Exclusiones',
          child: ChipListField(
            inputKey: const ValueKey('exclusions-input'),
            values: _exclusions,
            enabled: enabled,
            placeholder: 'Dirección sin proxy, ej. *.uci.cu',
            splitter: ProfileValidators.splitEntries,
            validator: (value) => ProfileValidators.exclusions([value]),
            onChanged: (values) => _changeList(() => _exclusions = values),
          ),
        ),
      ],
    );
  }

  Widget _sharing(bool enabled) {
    final caption = FluentTheme.of(context).typography.caption;
    final addresses = _gateway
        ? ref.watch(localAddressesProvider).value ?? const <String>[]
        : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Permitir que otros equipos usen este proxy'),
            ),
            const SizedBox(width: 12),
            ToggleSwitch(
              checked: _gateway,
              onChanged: enabled
                  ? (value) => _changeList(() => _gateway = value)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Quienes se conecten navegarán con su usuario y consumirán su '
          'cuota. Autorice solo equipos de confianza.',
          style: caption,
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: 'Equipos permitidos',
          child: ChipListField(
            values: _allowedHosts,
            enabled: enabled,
            placeholder: 'IP o red, ej. 192.168.1.20',
            splitter: ProfileValidators.splitEntries,
            validator: (value) => ProfileValidators.allowedHosts([value]),
            suggestions: [
              // `/24` is a guess, the usual size of a local network.
              for (final address in addresses)
                '${address.substring(0, address.lastIndexOf('.'))}.0/24',
            ],
            onChanged: (values) => _changeList(() => _allowedHosts = values),
          ),
        ),
        if (addresses.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Dirección para los otros equipos', style: caption),
          const SizedBox(height: 4),
          for (final address in addresses)
            _CopyableAddress('$address:${_localPort.text}'),
        ],
      ],
    );
  }
}

/// Explains what sharing means before it is turned on.
class _SharingIntro extends StatelessWidget {
  const _SharingIntro({
    super.key,
    required this.accent,
    required this.onActivate,
  });

  final Color accent;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final foreground =
        accent.computeLuminance() > 0.45 ? Colors.black : Colors.white;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.18),
              ),
              child: Icon(FluentIcons.share, size: 28, color: accent),
            ),
            const SizedBox(height: 16),
            Text('Comparta su conexión', style: theme.typography.subtitle),
            const SizedBox(height: 16),
            const _IntroPoint(
              icon: FluentIcons.globe,
              text: 'Otros equipos de su red navegan a través de este proxy',
            ),
            const _IntroPoint(
              icon: FluentIcons.warning,
              text: 'Usan su usuario y consumen su cuota',
            ),
            const _IntroPoint(
              icon: FluentIcons.lock,
              text: 'Solo entran los equipos que usted autorice',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton(
                onPressed: onActivate,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(accent),
                ),
                child: Text(
                  'Activar',
                  style: TextStyle(color: foreground),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPoint extends StatelessWidget {
  const _IntroPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: FluentTheme.of(context).typography.body),
          ),
        ],
      ),
    );
  }
}

/// Segmented control with a pill that slides to the selected section.
class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.selected,
    required this.onSelected,
  });

  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final count = SettingsSection.values.length;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment:
                Alignment(-1 + 2 * selected.index / (count - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.resources.controlFillColorDefault,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: theme.resources.controlStrokeColorDefault),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final section in SettingsSection.values)
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelected(section),
                      child: Center(
                        child: Text(
                          section.label,
                          style: theme.typography.caption?.copyWith(
                            fontWeight: section == selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopyableAddress extends ConsumerWidget {
  const _CopyableAddress(this.address);

  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(child: Text(address)),
        IconButton(
          icon: const Icon(FluentIcons.copy, size: 14),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: address));
            ref.read(messagesProvider.notifier).show('Dirección copiada');
          },
        ),
      ],
    );
  }
}
