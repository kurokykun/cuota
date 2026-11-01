import 'dart:math' as math;

import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Main control of the app: starts and stops the proxy, surrounded by the used
/// quota. While the proxy runs it breathes and waves leave it, so the state can
/// be told at a glance.
class PowerOrb extends StatefulWidget {
  const PowerOrb({
    super.key,
    required this.size,
    required this.phase,
    required this.accent,
    required this.ringColor,
    required this.fraction,
    required this.onPressed,
  });

  final double size;
  final ProxyPhase phase;
  final Color accent;
  final Color ringColor;

  /// Used quota between 0 and 1.
  final double fraction;
  final VoidCallback? onPressed;

  @override
  State<PowerOrb> createState() => _PowerOrbState();
}

class _PowerOrbState extends State<PowerOrb> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// Drives what moves in a single direction: the waves and the transition arc.
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  bool _hovered = false;
  bool _pressed = false;

  bool get _running => widget.phase == ProxyPhase.running;
  bool get _transitioning =>
      widget.phase == ProxyPhase.starting ||
      widget.phase == ProxyPhase.stopping;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(PowerOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _syncMotion();
  }

  void _syncMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.value = 0.5;
      _orbit.value = 0;
      return;
    }
    if (_running) {
      _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
    if (_running || _transitioning) {
      _orbit.repeat();
    } else {
      _orbit.stop();
      _orbit.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final enabled = widget.onPressed != null;
    final core = widget.size * 0.72;
    final scale = _pressed
        ? 0.96
        : _hovered && enabled
            ? 1.03
            : 1.0;
    final foreground = _running
        ? (widget.accent.computeLuminance() > 0.45
            ? Colors.black
            : Colors.white)
        : theme.resources.textFillColorPrimary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: _running ? 'Detener proxy' : 'Iniciar proxy',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: SizedBox.square(
              dimension: widget.size,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _running ? 1 : 0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, intensity, _) =>
                    TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: widget.fraction),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, fraction, _) => AnimatedBuilder(
                    animation: Listenable.merge([_breath, _orbit]),
                    builder: (context, _) {
                      final breath = Curves.easeInOut.transform(_breath.value);
                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          CustomPaint(
                            size: Size.square(widget.size),
                            painter: _RingPainter(
                              fraction: fraction,
                              color: widget.ringColor,
                              track: theme.resources.controlStrokeColorDefault,
                              accent: widget.accent,
                              orbit: _orbit.value,
                              intensity: intensity,
                              spinning: _transitioning,
                              coreRadius: core / 2,
                            ),
                          ),
                          _core(core, intensity, breath, foreground, theme),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _core(
    double diameter,
    double intensity,
    double breath,
    Color foreground,
    FluentThemeData theme,
  ) {
    final accent = widget.accent;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(theme.cardColor, accent, intensity),
        gradient: intensity == 0
            ? null
            : RadialGradient(
                colors: [
                  Color.lerp(
                      theme.cardColor,
                      Color.lerp(accent, Colors.white, 0.35 + 0.15 * breath),
                      intensity)!,
                  Color.lerp(theme.cardColor, accent, intensity)!,
                ],
              ),
        border: Border.all(
          color: _hovered && widget.onPressed != null
              ? accent
              : theme.resources.controlStrokeColorDefault,
        ),
        boxShadow: [
          // A tight halo plus a wide one read as light rather than as a shadow.
          BoxShadow(
            color: accent.withValues(alpha: intensity * (0.55 + 0.3 * breath)),
            blurRadius: 18 + 14 * breath,
            spreadRadius: 1 + 3 * breath,
          ),
          BoxShadow(
            color: accent.withValues(alpha: intensity * (0.3 + 0.25 * breath)),
            blurRadius: 60 + 40 * breath,
            spreadRadius: 10 + 22 * breath,
          ),
        ],
      ),
      child: Icon(
        FluentIcons.power_button,
        size: diameter * 0.35,
        color: foreground,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.accent,
    required this.orbit,
    required this.intensity,
    required this.spinning,
    required this.coreRadius,
  });

  final double fraction;
  final Color color;
  final Color track;
  final Color accent;

  /// Position of the moving elements, from 0 to 1.
  final double orbit;

  /// How far the proxy is into the running look, from 0 to 1.
  final double intensity;

  /// Whether to show the indeterminate arc of a transition.
  final bool spinning;
  final double coreRadius;

  static const _stroke = 6.0;
  static const _start = -math.pi / 2;
  static const _waves = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _stroke / 2 - 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    _paintWaves(canvas, center, radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
          arcRect, _start, 2 * math.pi * fraction, false, paint..color = color);
    }
    if (spinning) {
      canvas.drawArc(arcRect, _start + 2 * math.pi * (orbit * 2), math.pi / 2,
          false, paint..color = accent);
    }
  }

  void _paintWaves(Canvas canvas, Offset center, double ringRadius) {
    if (intensity == 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var wave = 0; wave < _waves; wave++) {
      final progress = (orbit + wave / _waves) % 1;
      final waveRadius = coreRadius + (ringRadius + 26 - coreRadius) * progress;
      paint.color = accent.withValues(
        alpha: intensity * 0.45 * (1 - progress) * (1 - progress),
      );
      canvas.drawCircle(center, waveRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      orbit != oldDelegate.orbit ||
      intensity != oldDelegate.intensity ||
      spinning != oldDelegate.spinning ||
      color != oldDelegate.color ||
      track != oldDelegate.track ||
      accent != oldDelegate.accent ||
      coreRadius != oldDelegate.coreRadius;
}
