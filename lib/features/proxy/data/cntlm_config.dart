import 'package:cuota/features/profiles/domain/profile.dart';

/// Password hashes printed by `cntlm -H`.
class CntlmHashes {
  const CntlmHashes(this.values);

  /// Directive name (`PassLM`, `PassNT`, `PassNTLMv2`) to hash.
  final Map<String, String> values;

  static final _line =
      RegExp(r'^(PassLM|PassNT|PassNTLMv2)\s+([0-9A-Fa-f]+)', multiLine: true);

  static CntlmHashes parse(String output) => CntlmHashes({
        for (final match in _line.allMatches(output))
          match.group(1)!: match.group(2)!,
      });

  bool get isComplete => values.length == 3;
}

/// Contents of the configuration file for [profile]. It only holds hashes,
/// never the password.
String buildCntlmConfig(Profile profile, CntlmHashes hashes) {
  final lines = [
    'Username\t${profile.username}',
    'Domain\t${profile.domain}',
    for (final entry in hashes.values.entries) '${entry.key}\t${entry.value}',
    'Proxy\t${profile.upstreamHost}:${profile.upstreamPort}',
    if (profile.noProxy.isNotEmpty) 'NoProxy\t${profile.noProxy.join(', ')}',
    'Listen\t${profile.localAddress}:${profile.localPort}',
    'Gateway\t${profile.gateway ? 'yes' : 'no'}',
    'Allow\t127.0.0.1',
    'Deny\t0/0',
  ];
  return '${lines.join('\n')}\n';
}
