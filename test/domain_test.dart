import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/features/account/domain/account.dart';
import 'package:cuota/features/profiles/domain/profile_validators.dart';
import 'package:cuota/features/quota/domain/quota.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('ProfileValidators', () {
    test('host accepts IPs and names, rejects trailing garbage', () {
      expect(ProfileValidators.host('10.0.0.1'), isNull);
      expect(ProfileValidators.host('proxy.uci.cu'), isNull);
      expect(ProfileValidators.host('proxy uci'), isNotNull);
      expect(ProfileValidators.host('host\nDeny 0/0'), isNotNull);
      expect(ProfileValidators.ipv4('10.0.0.1abc'), isNotNull);
      expect(ProfileValidators.ipv4('256.0.0.1'), isNotNull);
    });

    test('port covers the whole valid range', () {
      expect(ProfileValidators.port('1'), isNull);
      expect(ProfileValidators.port('65535'), isNull);
      expect(ProfileValidators.port('0'), isNotNull);
      expect(ProfileValidators.port('65536'), isNotNull);
      expect(ProfileValidators.port('abc'), isNotNull);
    });

    test('name rejects empty and taken values, ignoring case', () {
      expect(ProfileValidators.name('Casa "1"/2'), isNull);
      expect(ProfileValidators.name('  '), isNotNull);
      expect(ProfileValidators.name('CASA', taken: ['casa']), isNotNull);
    });

    test('entries are split whatever the separator is', () {
      expect(ProfileValidators.splitEntries('a,\n b; c  '), ['a', 'b', 'c']);
      expect(ProfileValidators.exclusions(['a', 'b c']), isNotNull);
      expect(ProfileValidators.exclusions(['a', '*uci.cu']), isNull);
    });

    test('allowed hosts accept addresses and networks, never everyone', () {
      expect(ProfileValidators.allowedHosts(['192.168.1.20']), isNull);
      expect(ProfileValidators.allowedHosts(['192.168.1.0/24']), isNull);
      expect(ProfileValidators.allowedHosts(['0.0.0.0/0']), isNotNull);
      expect(ProfileValidators.allowedHosts(['10.0.0.0/33']), isNotNull);
      expect(ProfileValidators.allowedHosts(['equipo']), isNotNull);
    });

    test('gateway mode requires at least one allowed host', () {
      final shared = sampleProfile().copyWith(gateway: true);

      expect(() => ProfileValidators.ensureRunnable(shared),
          throwsA(isA<ValidationFailure>()));
      ProfileValidators.ensureRunnable(
          shared.copyWith(allowedHosts: ['192.168.1.0/24']));
    });

    test('credentials are required to run the proxy', () {
      expect(
        () => ProfileValidators.ensureRunnable(
            sampleProfile().copyWith(password: '')),
        throwsA(isA<ValidationFailure>()),
      );
      ProfileValidators.ensureRunnable(sampleProfile());
    });
  });

  group('Quota.usedFraction', () {
    test('handles normal, exceeded and empty quotas', () {
      expect(const Quota(total: 400, used: 100).usedFraction, 0.25);
      expect(const Quota(total: 400, used: 500).usedFraction, 1);
      expect(const Quota(total: 0, used: 0).usedFraction, 0);
      expect(const Quota(total: 0, used: 5).usedFraction, 1);
    });
  });

  group('PasswordPolicy', () {
    test('requires every character class', () {
      expect(PasswordPolicy.isStrong('Abcdef1!'), isTrue);
      expect(PasswordPolicy.isStrong('abcdef1!'), isFalse);
      expect(PasswordPolicy.isStrong('Abc1!'), isFalse);
    });
  });
}
