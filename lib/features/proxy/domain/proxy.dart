import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_repository.dart';
import 'package:cuota/features/profiles/domain/profile_validators.dart';

abstract interface class ProxyGateway {
  /// Returns once the proxy accepts connections, or throws a
  /// [ProxyStartFailure].
  Future<void> start(Profile profile);

  /// Does nothing when the proxy is not running.
  Future<void> stop();

  /// Emits a description each time the proxy terminates without being asked.
  Stream<String> get unexpectedExits;
}

class StartProxy {
  const StartProxy(this._profiles, this._proxy);

  final ProfileRepository _profiles;
  final ProxyGateway _proxy;

  /// Saves [profile] and runs the proxy with it. Returns a warning when the
  /// proxy started but the profile could not be stored.
  Future<String?> call(Profile profile) async {
    ProfileValidators.ensureRunnable(profile);
    String? warning;
    try {
      await _profiles.save(profile);
    } on SecretStorageFailure catch (failure) {
      warning = failure.message;
    }
    await _proxy.start(profile);
    return warning;
  }
}

class StopProxy {
  const StopProxy(this._proxy);

  final ProxyGateway _proxy;

  Future<void> call() => _proxy.stop();
}
