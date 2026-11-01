import 'package:cuota/core/errors/failures.dart';

class PasswordChange {
  const PasswordChange({
    required this.username,
    required this.current,
    required this.replacement,
    required this.confirmation,
  });

  final String username;
  final String current;
  final String replacement;
  final String confirmation;
}

abstract interface class AccountRepository {
  Future<void> changePassword(PasswordChange change);
}

class PasswordRequirement {
  const PasswordRequirement(this.label, this.isMet);

  final String label;
  final bool Function(String value) isMet;
}

abstract final class PasswordPolicy {
  static final _strong =
      RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');

  static const description = 'Use al menos 8 caracteres con mayúscula, '
      'minúscula, número y uno de !@#\$&*~';

  static bool isStrong(String value) => _strong.hasMatch(value);

  static final requirements = [
    PasswordRequirement('Al menos 8 caracteres', (v) => v.length >= 8),
    PasswordRequirement(
        'Una letra mayúscula', (v) => v.contains(RegExp('[A-Z]'))),
    PasswordRequirement(
        'Una letra minúscula', (v) => v.contains(RegExp('[a-z]'))),
    PasswordRequirement('Un número', (v) => v.contains(RegExp('[0-9]'))),
    PasswordRequirement(
        r'Un símbolo: ! @ # $ & * ~', (v) => v.contains(RegExp(r'[!@#$&*~]'))),
  ];
}

class ChangePassword {
  const ChangePassword(this._repository);

  final AccountRepository _repository;

  Future<void> call(PasswordChange change) {
    if (change.username.isEmpty || change.current.isEmpty) {
      throw const ValidationFailure('Complete el usuario y la contraseña');
    }
    if (!PasswordPolicy.isStrong(change.replacement)) {
      throw const ValidationFailure(PasswordPolicy.description);
    }
    if (change.replacement != change.confirmation) {
      throw const ValidationFailure('Las contraseñas no coinciden');
    }
    return _repository.changePassword(change);
  }
}
