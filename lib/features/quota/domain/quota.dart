import 'package:cuota/features/profiles/domain/profile.dart';

class Quota {
  const Quota({required this.total, required this.used});

  final double total;
  final double used;

  /// Used share between 0 and 1, also for an empty or exceeded quota.
  double get usedFraction {
    if (total <= 0) return used > 0 ? 1 : 0;
    return (used / total).clamp(0.0, 1.0);
  }
}

abstract interface class QuotaRepository {
  Future<Quota> fetch(Profile profile);
}

class GetQuota {
  const GetQuota(this._repository);

  final QuotaRepository _repository;

  Future<Quota> call(Profile profile) => _repository.fetch(profile);
}
