import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_repository.dart';
import 'package:cuota/features/profiles/domain/profile_validators.dart';

class LoadProfiles {
  const LoadProfiles(this._repository);

  final ProfileRepository _repository;

  Future<ProfileCatalog> call() => _repository.loadAll();
}

class CreateProfile {
  const CreateProfile(this._repository);

  final ProfileRepository _repository;

  /// Rejects invalid names and names already in use by [existing].
  Future<Profile> call(
    String name, {
    required Iterable<Profile> existing,
    ProfileColor color = ProfileColor.teal,
  }) {
    final error =
        ProfileValidators.name(name, taken: existing.map((p) => p.name));
    if (error != null) throw ValidationFailure(error);
    return _repository.create(name.trim(), color: color);
  }
}

class SaveProfile {
  const SaveProfile(this._repository);

  final ProfileRepository _repository;

  Future<void> call(Profile profile) => _repository.save(profile);
}

class DeleteProfile {
  const DeleteProfile(this._repository);

  final ProfileRepository _repository;

  Future<void> call(String id) => _repository.delete(id);
}
