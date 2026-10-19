import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/usecases/bootstrap_app_usecase.dart';
import 'package:Prism/features/startup/startup.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockBootstrapAppUseCase extends Mock implements BootstrapAppUseCase {}

class _SplashRouter extends AppRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(SplashWidgetRoute.name, builder: (_) => const SplashWidget()),
    ),
    AutoRoute(
      path: '/onboarding/v2',
      page: PageInfo(OnboardingV2ShellRoute.name, builder: (_) => const Text(OnboardingV2ShellRoute.name)),
    ),
    AutoRoute(
      path: '/dashboard',
      page: PageInfo(DashboardRoute.name, builder: (_) => const Text(DashboardRoute.name)),
    ),
  ];
}

StartupConfigEntity _config(String obsoleteAppVersion) => StartupConfigEntity(
  topImageLink: 'top',
  bannerText: 'banner',
  bannerTextOn: true,
  bannerUrl: 'url',
  obsoleteAppVersion: obsoleteAppVersion,
  verifiedUsers: const <String>[],
  premiumCollections: const <String>[],
  aiEnabled: true,
  aiRolloutPercent: 100,
  aiSubmitEnabled: true,
  aiVariationsEnabled: true,
  useRcPaywalls: true,
  onboardingV2Enabled: true,
);

void main() {
  late InMemoryLocalStore store;
  late _MockBootstrapAppUseCase bootstrap;
  late Completer<Result<StartupConfigEntity>> bootstrapResult;
  late StartupBloc bloc;
  late _SplashRouter router;

  setUp(() {
    store = InMemoryLocalStore();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store));
    bootstrap = _MockBootstrapAppUseCase();
    bootstrapResult = Completer<Result<StartupConfigEntity>>();
    when(() => bootstrap(const NoParams())).thenAnswer((_) => bootstrapResult.future);
    bloc = StartupBloc(bootstrap)..add(const StartupEvent.started(currentVersion: '3.0.0'));
    router = _SplashRouter();
  });

  tearDown(() async {
    await bloc.close();
    await getIt.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<StartupBloc>.value(
        value: bloc,
        child: MaterialApp.router(
          routerConfig: router.config(),
          builder: (context, child) => ObsoleteVersionGate(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finishBootstrap(WidgetTester tester, Result<StartupConfigEntity> result) async {
    bootstrapResult.complete(result);
    await tester.runAsync(() => bloc.stream.first);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> storeOnboarded() => store.set(PersistenceKeys.settings(OnboardingV2Keys.onboardedNew), true);

  Future<void> storeObsoleteVersion(String version) =>
      store.set(PersistenceKeys.settings(PersistenceKeys.obsoleteAppVersion), version);

  testWidgets('a returning user with a safe stored version reaches the dashboard before bootstrap ends', (
    tester,
  ) async {
    await storeOnboarded();
    await storeObsoleteVersion('1.0.0');

    await pumpApp(tester);

    expect(bloc.state.config, isNull);
    expect(find.text(DashboardRoute.name), findsOneWidget);
  });

  testWidgets('a returning user with no stored version waits for bootstrap', (tester) async {
    await storeOnboarded();

    await pumpApp(tester);
    expect(find.text(DashboardRoute.name), findsNothing);

    await finishBootstrap(tester, Result.success(_config('1.0.0')));

    expect(find.text(DashboardRoute.name), findsOneWidget);
  });

  testWidgets('a stored version newer than this app does not skip bootstrap', (tester) async {
    await storeOnboarded();
    await storeObsoleteVersion('99.0.0');

    await pumpApp(tester);

    expect(find.text(DashboardRoute.name), findsNothing);
  });

  testWidgets('a user who has not onboarded does not skip bootstrap', (tester) async {
    await storeObsoleteVersion('1.0.0');

    await pumpApp(tester);

    expect(find.text(DashboardRoute.name), findsNothing);
    expect(find.text(OnboardingV2ShellRoute.name), findsNothing);
  });

  testWidgets('bootstrap reporting an obsolete version after the fast path shows the update screen', (tester) async {
    await storeOnboarded();
    await storeObsoleteVersion('1.0.0');
    await pumpApp(tester);
    expect(find.text(DashboardRoute.name), findsOneWidget);

    await finishBootstrap(tester, Result.success(_config('99.0.0')));

    expect(find.byType(OldVersion), findsOneWidget);
    expect(find.text(DashboardRoute.name), findsNothing);
  });

  testWidgets('a failed bootstrap after the fast path leaves the user on the dashboard', (tester) async {
    await storeOnboarded();
    await storeObsoleteVersion('1.0.0');
    await pumpApp(tester);

    await finishBootstrap(tester, Result.error(const ServerFailure('boom')));

    expect(find.text(DashboardRoute.name), findsOneWidget);
  });
}
