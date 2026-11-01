import 'package:cuota/features/profiles/domain/profile.dart';

/// On-disk format of a profile. The password is kept out of the file; files
/// written by older versions may still carry it under [legacyPasswordKey].
abstract final class ProfileJson {
  static const legacyPasswordKey = 'pass';

  /// Throws if [json] misses a required field or has an unexpected type.
  static Profile fromJson(String id, Map<String, dynamic> json) => Profile(
        id: id,
        name: json['name'] as String,
        color: ProfileColor.fromName(json['color'] as String?),
        username: json['usser'] as String,
        password: json[legacyPasswordKey] as String? ?? '',
        localAddress: json['local_proxy'] as String,
        localPort: json['local_port'].toString(),
        upstreamHost: json['upstream_proxy'] as String,
        upstreamPort: json['upstream_proxy_port'].toString(),
        domain: json['domain'] as String,
        noProxy: (json['no_proxy'] as List).cast<String>().toList(),
        gateway: json['gateway'] as bool? ?? false,
      );

  static Map<String, dynamic> toJson(Profile profile) => {
        'name': profile.name,
        'color': profile.color.name,
        'usser': profile.username,
        'local_port': profile.localPort,
        'local_proxy': profile.localAddress,
        'upstream_proxy': profile.upstreamHost,
        'upstream_proxy_port': profile.upstreamPort,
        'domain': profile.domain,
        'no_proxy': profile.noProxy,
        'gateway': profile.gateway,
      };
}
