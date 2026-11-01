import 'package:cuota/core/providers.dart';
import 'package:cuota/features/profiles/data/file_profile_repository.dart';
import 'package:cuota/features/profiles/data/secret_store.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_repository.dart';
import 'package:cuota/features/profiles/domain/profile_use_cases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secretStoreProvider =
    Provider<SecretStore>((ref) => const KeyringSecretStore());

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FileProfileRepository(
    directory: ref.watch(appPathsProvider).root,
    secrets: ref.watch(secretStoreProvider),
  ),
);

final profilesControllerProvider =
    AsyncNotifierProvider<ProfilesController, ProfileCatalog>(
        ProfilesController.new);

class ProfilesController extends AsyncNotifier<ProfileCatalog> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  Future<ProfileCatalog> build() async {
    final catalog = await LoadProfiles(_repository)();
    if (!ref.read(appPathsProvider).isFirstRun ||
        catalog.profiles.isNotEmpty ||
        catalog.corruptFiles.isNotEmpty) {
      return catalog;
    }
    final seed = await _repository.create('Perfil nuevo',
        color: ProfileColor.red);
    return ProfileCatalog(profiles: [seed]);
  }

  List<Profile> get _profiles => state.value?.profiles ?? const [];

  /// Throws a failure when the name is rejected or the file cannot be written.
  Future<Profile> create(String name) async {
    final profile = await CreateProfile(_repository)(name, existing: _profiles);
    _publish([..._profiles, profile]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
    return profile;
  }

  Future<void> setColor(String id, ProfileColor color) async {
    final profile = _profiles.firstWhere((p) => p.id == id).copyWith(
          color: color,
        );
    await SaveProfile(_repository)(profile);
    replace(profile);
  }

  Future<void> delete(String id) async {
    await DeleteProfile(_repository)(id);
    _publish(_profiles.where((p) => p.id != id).toList());
  }

  /// Updates the in-memory copy of a profile already persisted elsewhere.
  void replace(Profile profile) {
    _publish([
      for (final p in _profiles) p.id == profile.id ? profile : p,
    ]);
  }

  void _publish(List<Profile> profiles) {
    final current = state.value;
    state = AsyncData(ProfileCatalog(
      profiles: profiles,
      corruptFiles: current?.corruptFiles ?? const [],
      secretsAvailable: current?.secretsAvailable ?? true,
    ));
  }
}

final selectedProfileIdProvider =
    NotifierProvider<SelectedProfileId, String?>(SelectedProfileId.new);

class SelectedProfileId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

/// The selected profile, falling back to the first one available.
final selectedProfileProvider = Provider<Profile?>((ref) {
  final profiles =
      ref.watch(profilesControllerProvider).value?.profiles ?? const [];
  if (profiles.isEmpty) return null;
  final id = ref.watch(selectedProfileIdProvider);
  return profiles.firstWhere((p) => p.id == id, orElse: () => profiles.first);
});
