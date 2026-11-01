import 'package:cuota/features/profiles/domain/profile.dart';

abstract interface class ProfileRepository {
  Future<ProfileCatalog> loadAll();

  /// Creates a profile with the default settings and no credentials.
  Future<Profile> create(String name, {ProfileColor color});

  /// Persists [profile], throwing without changing the stored data on failure.
  Future<void> save(Profile profile);

  Future<void> delete(String id);
}
