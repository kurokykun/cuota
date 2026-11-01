enum ProfileColor {
  yellow,
  orange,
  red,
  magenta,
  purple,
  blue,
  teal,
  green,
  black,
  grey;

  static ProfileColor fromName(String? name) => values.firstWhere(
        (color) => color.name == name,
        orElse: () => ProfileColor.teal,
      );
}

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.color,
    required this.username,
    required this.password,
    required this.localAddress,
    required this.localPort,
    required this.upstreamHost,
    required this.upstreamPort,
    required this.domain,
    required this.noProxy,
    required this.gateway,
  });

  /// Stable identifier, independent from the display [name].
  final String id;
  final String name;
  final ProfileColor color;
  final String username;
  final String password;
  final String localAddress;
  final String localPort;
  final String upstreamHost;
  final String upstreamPort;
  final String domain;
  final List<String> noProxy;
  final bool gateway;

  Profile copyWith({
    String? name,
    ProfileColor? color,
    String? username,
    String? password,
    String? localAddress,
    String? localPort,
    String? upstreamHost,
    String? upstreamPort,
    String? domain,
    List<String>? noProxy,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        username: username ?? this.username,
        password: password ?? this.password,
        localAddress: localAddress ?? this.localAddress,
        localPort: localPort ?? this.localPort,
        upstreamHost: upstreamHost ?? this.upstreamHost,
        upstreamPort: upstreamPort ?? this.upstreamPort,
        domain: domain ?? this.domain,
        noProxy: noProxy ?? this.noProxy,
        gateway: gateway,
      );
}

/// Result of loading the stored profiles.
class ProfileCatalog {
  const ProfileCatalog({
    required this.profiles,
    this.corruptFiles = const [],
    this.secretsAvailable = true,
  });

  final List<Profile> profiles;

  /// Files skipped because they could not be parsed.
  final List<String> corruptFiles;

  /// False when the keyring could not be reached while loading.
  final bool secretsAvailable;
}
