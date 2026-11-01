/// Expected errors, with a message that can be shown to the user as is.
sealed class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

/// The system keyring could not be read or written.
class SecretStorageFailure extends Failure {
  const SecretStorageFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// The server certificate could not be verified.
class TlsFailure extends Failure {
  const TlsFailure(super.message);
}

class ServerResponseFailure extends Failure {
  const ServerResponseFailure(super.message);
}

class ProxyStartFailure extends Failure {
  const ProxyStartFailure(super.message);
}
