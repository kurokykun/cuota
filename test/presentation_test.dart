import 'dart:async';

import 'package:cuota/core/config/app_paths.dart';
import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/providers.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/profiles/domain/profile_repository.dart';
import 'package:cuota/features/profiles/presentation/profiles_page.dart';
import 'package:cuota/features/profiles/presentation/profiles_providers.dart';
import 'package:cuota/features/proxy/domain/proxy.dart';
import 'package:cuota/features/proxy/presentation/proxy_providers.dart';
import 'package:cuota/features/quota/domain/quota.dart';
import 'package:cuota/features/quota/presentation/quota_providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakeProfiles implements ProfileRepository {
  FakeProfiles(this.profiles);

  final List<Profile> profiles;
  final saved = <Profile>[];

  @override
  Future<ProfileCatalog> loadAll() async =>
      ProfileCatalog(profiles: List.of(profiles));

  @override
  Future<Profile> create(String name, {ProfileColor color = ProfileColor.teal}) async =>
      sampleProfile(id: name.toLowerCase()).copyWith(name: name, color: color);

  @override
  Future<void> save(Profile profile) async => saved.add(profile);

  @override
  Future<void> delete(String id) async {}
}

class FakeProxy implements ProxyGateway {
  final exits = StreamController<String>.broadcast();
  Failure? startFailure;
  int starts = 0;
  int stops = 0;

  @override
  Future<void> start(Profile profile) async {
    starts++;
    if (startFailure != null) throw startFailure!;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Stream<String> get unexpectedExits => exits.stream;

  @override
  Stream<void> get quotaExhausted => const Stream.empty();

  @override
  Future<String?> runningProfileId() async => null;
}

class FakeQuota implements QuotaRepository {
  Object result = const Quota(total: 400, used: 100);

  @override
  Future<Quota> fetch(Profile profile) async {
    final value = result;
    if (value is Quota) return value;
    throw value;
  }
}

void main() {
  late FakeProfiles profiles;
  late FakeProxy proxy;
  late FakeQuota quota;

  List<Override> overrides() => [
        appPathsProvider.overrideWithValue(const AppPaths(root: '/nonexistent')),
        profileRepositoryProvider.overrideWithValue(profiles),
        proxyGatewayProvider.overrideWithValue(proxy),
        quotaRepositoryProvider.overrideWithValue(quota),
      ];

  setUp(() {
    profiles = FakeProfiles([sampleProfile()]);
    proxy = FakeProxy();
    quota = FakeQuota();
  });

  group('controllers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer.test(
        overrides: overrides(),
        retry: (_, _) => null,
      );
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('starting saves the draft and fetches the quota', () async {
      container.listen(quotaControllerProvider, (_, _) {});
      await container.read(profilesControllerProvider.future);
      final draft = sampleProfile().copyWith(noProxy: ['otro']);

      await container.read(proxyControllerProvider.notifier).start(draft);
      await settle();

      expect(container.read(proxyControllerProvider).phase, ProxyPhase.running);
      expect(profiles.saved.single.noProxy, ['otro']);
      expect(container.read(selectedProfileProvider)!.noProxy, ['otro']);
      expect(container.read(quotaControllerProvider).quota!.used, 100);
    });

    test('invalid data never reaches the proxy', () async {
      await container
          .read(proxyControllerProvider.notifier)
          .start(sampleProfile().copyWith(upstreamPort: '99999'));

      final status = container.read(proxyControllerProvider);
      expect(status.phase, ProxyPhase.stopped);
      expect(status.error, isNotNull);
      expect(proxy.starts, 0);
    });

    test('a failed start is reported instead of claiming success', () async {
      proxy.startFailure = const ProxyStartFailure('puerto ocupado');

      await container.read(proxyControllerProvider.notifier).start(sampleProfile());

      final status = container.read(proxyControllerProvider);
      expect(status.phase, ProxyPhase.stopped);
      expect(status.error, 'puerto ocupado');
    });

    test('a proxy crash stops the session and reports why', () async {
      await container.read(proxyControllerProvider.notifier).start(sampleProfile());

      proxy.exits.add('cntlm murió');
      await settle();

      final status = container.read(proxyControllerProvider);
      expect(status.phase, ProxyPhase.stopped);
      expect(status.error, 'cntlm murió');
    });

    test('a quota failure keeps the last value and shows the reason', () async {
      container.listen(quotaControllerProvider, (_, _) {});
      final proxyController = container.read(proxyControllerProvider.notifier);
      await proxyController.start(sampleProfile());
      await settle();
      await proxyController.stop();
      quota.result = const TlsFailure('certificado');

      await proxyController.start(sampleProfile());
      await settle();

      final state = container.read(quotaControllerProvider);
      expect(state.quota!.total, 400);
      expect(state.error, 'certificado');
    });

    test('duplicate names are rejected', () async {
      await container.read(profilesControllerProvider.future);

      expect(
        () => container
            .read(profilesControllerProvider.notifier)
            .create('perfil'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('ProfilesPage', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 608);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: overrides(),
        child: FluentApp(
          theme: FluentThemeData(brightness: Brightness.dark),
          home: const ProfilesPage(),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the empty state without profiles', (tester) async {
      profiles = FakeProfiles([]);

      await pump(tester);

      expect(find.textContaining('Ningún perfil'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('summarizes the configuration without opening it',
        (tester) async {
      await pump(tester);

      expect(find.text('usuario'), findsOneWidget);
      expect(find.text('10.0.0.1:8080'), findsOneWidget);
      expect(find.text('Desactivado'), findsOneWidget);
    });

    testWidgets('shows that sharing is active on the main view',
        (tester) async {
      profiles = FakeProfiles([
        sampleProfile().copyWith(gateway: true, allowedHosts: ['10.8.3.38']),
      ]);

      await pump(tester);

      expect(find.text('Activado · 1 equipo'), findsOneWidget);
    });

    testWidgets('saves settings on its own and starts with them',
        (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('row-server')));
      await tester.pumpAndSettle();
      expect(find.text('localhost'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('exclusions-input')), 'uno, dos');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(seconds: 1));
      expect(profiles.saved.last.noProxy, ['localhost', '10.*', 'uno', 'dos']);

      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('power-orb')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(proxy.starts, 1);
      expect(find.text('Conectado'), findsOneWidget);
    });

    testWidgets('switches between profiles from the header', (tester) async {
      profiles = FakeProfiles([
        sampleProfile(id: 'a').copyWith(name: 'Casa'),
        sampleProfile(id: 'b').copyWith(name: 'Universidad'),
      ]);
      await pump(tester);
      expect(find.text('Casa'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Universidad'));
      await tester.pumpAndSettle();

      expect(find.text('Universidad'), findsOneWidget);
      expect(find.text('Casa'), findsNothing);
    });

    testWidgets('the profile actions are in the header menu', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar contraseña'), findsOneWidget);
      expect(find.text('Eliminar perfil'), findsOneWidget);
    });

    testWidgets('the profile icon opens the color palette', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('profile-color')));
      await tester.pumpAndSettle();

      expect(find.text('Color del perfil'), findsOneWidget);
    });

    testWidgets('asks for credentials instead of failing to start',
        (tester) async {
      profiles = FakeProfiles([sampleProfile(password: '')]);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('power-orb')));
      await tester.pumpAndSettle();

      expect(proxy.starts, 0);
      expect(find.text('Contraseña'), findsOneWidget);
    });
  });
}
