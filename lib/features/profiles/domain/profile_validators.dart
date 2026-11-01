import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/features/profiles/domain/profile.dart';

/// Field rules. Each validator returns an error message, or null when valid.
abstract final class ProfileValidators {
  static final _ipv4 = RegExp(
      r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$');
  static final _hostname =
      RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$');
  static final _noSpaces = RegExp(r'^\S+$');
  static final _controlChars = RegExp(r'[\x00-\x1f\x7f]');
  static final _exclusion = RegExp(r'^[^\s,]+$');

  static const maxNameLength = 40;

  static String? name(String? value, {Iterable<String> taken = const []}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El nombre es obligatorio';
    if (text.length > maxNameLength) {
      return 'El nombre admite hasta $maxNameLength caracteres';
    }
    if (_controlChars.hasMatch(text)) {
      return 'El nombre contiene caracteres no válidos';
    }
    final lower = text.toLowerCase();
    if (taken.any((other) => other.toLowerCase() == lower)) {
      return 'Ya existe un perfil con ese nombre';
    }
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.isEmpty) return 'El usuario es obligatorio';
    if (!_noSpaces.hasMatch(value)) return 'El usuario no admite espacios';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es obligatoria';
    if (_controlChars.hasMatch(value)) {
      return 'La contraseña contiene caracteres no válidos';
    }
    return null;
  }

  static String? domain(String? value) {
    if (value == null || value.isEmpty) return 'El dominio es obligatorio';
    if (!_noSpaces.hasMatch(value)) return 'El dominio no admite espacios';
    return null;
  }

  static String? ipv4(String? value) {
    if (value == null || !_ipv4.hasMatch(value)) {
      return 'La dirección IP no es válida';
    }
    return null;
  }

  static String? host(String? value) {
    if (value == null || value.length > 253 || !_hostname.hasMatch(value)) {
      return 'El servidor remoto no es válido';
    }
    return null;
  }

  static String? port(String? value) {
    final port = int.tryParse(value ?? '');
    if (port == null || port < 1 || port > 65535) {
      return 'El puerto debe estar entre 1 y 65535';
    }
    return null;
  }

  static String? exclusions(Iterable<String> values) {
    for (final value in values) {
      if (!_exclusion.hasMatch(value)) {
        return 'Exclusión no válida: "$value"';
      }
    }
    return null;
  }

  /// Splits the text of the exclusions field, one entry per line.
  static List<String> parseExclusions(String text) => text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  /// Throws a [ValidationFailure] unless [profile] can be used to run the proxy.
  static void ensureRunnable(Profile profile) {
    final error = username(profile.username) ??
        password(profile.password) ??
        host(profile.upstreamHost) ??
        port(profile.upstreamPort) ??
        ipv4(profile.localAddress) ??
        port(profile.localPort) ??
        domain(profile.domain) ??
        exclusions(profile.noProxy);
    if (error != null) throw ValidationFailure(error);
  }
}
