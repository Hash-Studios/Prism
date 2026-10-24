import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/deep_link_startup_gate.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _DenyGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) => resolver.next(false);
}

class _LinkTestRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(path: '/', page: _page(SplashWidgetRoute.name)),
    AutoRoute(path: '/onboarding/v2', page: _page(OnboardingV2ShellRoute.name)),
    AutoRoute(
      path: '/dashboard',
      page: PageInfo(
        DashboardRoute.name,
        builder: (_) => const AutoTabsRouter(
          routes: <PageRouteInfo>[HomeTabRoute(), SearchTabRoute(), RewardsTabRoute(), CollectionTabRoute()],
        ),
      ),
      children: <AutoRoute>[
        AutoRoute(path: 'home', page: _page(HomeTabRoute.name)),
        AutoRoute(
          path: 'search',
          page: PageInfo(SearchTabRoute.name, builder: (_) => const AutoRouter()),
          children: <AutoRoute>[
            AutoRoute(path: '', page: _page(SearchRoute.name)),
            AutoRoute(path: 'users', page: _page(UserSearchRoute.name)),
          ],
        ),
        AutoRoute(path: 'rewards', page: _page(RewardsTabRoute.name)),
        AutoRoute(path: 'collection', page: _page(CollectionTabRoute.name)),
      ],
    ),
    AutoRoute(path: '/downloads', page: _page(DownloadRoute.name)),
    AutoRoute(path: '/about', page: _page(AboutRoute.name)),
    AutoRoute(path: '/notifications', page: _page(NotificationRoute.name)),
    AutoRoute(path: '/shop', page: _page(ShopRoute.name), guards: <AutoRouteGuard>[_DenyGuard()]),
    AutoRoute(path: '/not-found', page: _page(NotFoundRoute.name)),
  ];

  static PageInfo _page(String name) => PageInfo(name, builder: (_) => Text(name));
}

class _ResolvingNavigation extends DeepLinkNavigation {
  const _ResolvingNavigation(this.resolve);

  final Future<DeepLinkRouteResolution> Function(DeepLinkActionEntity action) resolve;

  @override
  Future<DeepLinkRouteResolution> resolveAction(DeepLinkActionEntity action) => resolve(action);
}

void main() {
  late _LinkTestRouter router;
  late List<AnalyticsEvent> events;
  late DeepLinkDispatcher dispatcher;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  DeepLinkDispatcher create({
    Future<bool> Function()? whenReady,
    Future<bool> Function()? whenBootstrapped,
    DeepLinkNavigation? navigation,
  }) => DeepLinkDispatcher(
    router: router,
    whenReady: whenReady ?? () async => true,
    whenBootstrapped: whenBootstrapped,
    navigation: navigation ?? const DeepLinkNavigation(),
    track: (event) async => events.add(event),
  );

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();
    unawaited(router.replaceAll(const <PageRouteInfo>[DashboardRoute()]));
    await tester.pumpAndSettle();
    dispatcher.dispose();
    dispatcher = create();
  }

  List<DeepLinkNavigationResultEvent> results() => events.whereType<DeepLinkNavigationResultEvent>().toList();

  setUp(() {
    router = _LinkTestRouter();
    events = <AnalyticsEvent>[];
    dispatcher = create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
  });

  tearDown(() {
    dispatcher.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  testWidgets('external, push, and in-app links share navigation and source-aware outcomes', (tester) async {
    await mount(tester);
    for (final source in DeepLinkSourceValue.values) {
      final result = dispatcher.openUri(Uri.parse('https://prismwalls.com/downloads'), source: source);
      await tester.pumpAndSettle();
      expect(events.whereType<DeepLinkResolvedEvent>(), isNotEmpty);
      expect(router.topRoute.name, DownloadRoute.name);
      expect(await result, DeepLinkDispatchResult.navigated);
      expect(router.topRoute.name, DownloadRoute.name);
    }
    expect(events.whereType<DeepLinkReceivedEvent>().map((event) => event.source), DeepLinkSourceValue.values);
    expect(results().map((event) => event.source), DeepLinkSourceValue.values);
    expect(results().map((event) => event.result), everyElement(EventResultValue.navigated));
  });

  testWidgets('a second queued link completes while the first page is still on the stack', (tester) async {
    await mount(tester);
    final first = dispatcher.openUri(Uri.parse('prism://downloads'), source: DeepLinkSourceValue.appLinks);
    final second = dispatcher.openUri(Uri.parse('prism://about'), source: DeepLinkSourceValue.appLinks);
    await tester.pumpAndSettle();
    expect(await first, DeepLinkDispatchResult.navigated);
    expect(await second, DeepLinkDispatchResult.navigated);
    expect(
      router.stackData.map((route) => route.name),
      containsAllInOrder(<String>[DownloadRoute.name, AboutRoute.name]),
    );
  });

  testWidgets('cold startup blocks resource hydration and navigation until ready', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    final ready = Completer<bool>();
    var resolved = 0;
    dispatcher = create(
      whenReady: () => ready.future,
      navigation: _ResolvingNavigation((_) async {
        resolved++;
        return const DeepLinkRouteResolution.route(DownloadRoute());
      }),
    );
    final result = dispatcher.openUri(Uri.parse('prism://downloads'), source: DeepLinkSourceValue.appLinks);
    await tester.pump();
    expect(resolved, 0);
    expect(results(), isEmpty);
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.navigated);
    expect(resolved, 1);
  });

  testWidgets('a cold platform URL arriving after the root survives splash and onboarding replacements', (
    tester,
  ) async {
    dispatcher.dispose();
    final gate = DeepLinkStartupGate(router: router);
    dispatcher = create(whenReady: gate.whenReady, whenBootstrapped: gate.whenBootstrapped);
    addTearDown(gate.dispose);
    final delivered = <bool>[];
    final config = router.config(
      deepLinkTransformer: (uri) async => const DeepLinkParser().transform(uri),
      deepLinkBuilder: (link) {
        delivered.add(link.initial);
        if (link.initial && link.uri.path == '/') return DeepLink.defaultPath;
        unawaited(dispatcher.openUri(link.uri, source: DeepLinkSourceValue.appLinks));
        return link.initial ? DeepLink.defaultPath : DeepLink.none;
      },
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    final state = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('prism://about')),
    );
    await config.routerDelegate.setNewRoutePath(state);
    await tester.pumpAndSettle();
    expect(delivered, <bool>[true, false]);
    expect(router.topRoute.name, SplashWidgetRoute.name);
    gate.markBootstrapCompleted();
    unawaited(router.replaceAll(<PageRouteInfo>[OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    expect(results(), isEmpty);
    unawaited(router.replaceAll(const <PageRouteInfo>[SplashWidgetRoute()]));
    await tester.pumpAndSettle();
    expect(results(), isEmpty);
    unawaited(router.replaceAll(const <PageRouteInfo>[DashboardRoute()]));
    await tester.pumpAndSettle();
    expect(router.topRoute.name, AboutRoute.name);
    expect(results().single.result, EventResultValue.navigated);
  });

  testWidgets('an onboarding launch link acknowledges mandatory onboarding without reopening it after completion', (
    tester,
  ) async {
    await mount(tester);
    unawaited(router.replaceAll(const <PageRouteInfo>[SplashWidgetRoute()]));
    await tester.pumpAndSettle();
    dispatcher.dispose();
    final bootstrap = Completer<bool>();
    final ready = Completer<bool>();
    dispatcher = create(whenBootstrapped: () => bootstrap.future, whenReady: () => ready.future);
    final result = dispatcher.openUri(Uri.parse('prism://onboarding/v2'), source: DeepLinkSourceValue.appLinks);
    await tester.pump();
    expect(results(), isEmpty);
    bootstrap.complete(true);
    await tester.pump();
    expect(router.topRoute.name, SplashWidgetRoute.name);
    unawaited(router.replaceAll(<PageRouteInfo>[OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), hasLength(1));
    unawaited(router.replaceAll(const <PageRouteInfo>[DashboardRoute()]));
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(router.topRoute.name, HomeTabRoute.name);
    expect(results(), hasLength(1));
  });

  testWidgets('a referral is saved after bootstrap while another link is waiting for onboarding', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    final bootstrap = Completer<bool>();
    final ready = Completer<bool>();
    final List<DeepLinkActionEntity> saved = <DeepLinkActionEntity>[];
    dispatcher = create(
      whenBootstrapped: () => bootstrap.future,
      whenReady: () => ready.future,
      navigation: _ResolvingNavigation((action) async {
        saved.add(action);
        return const DeepLinkRouteResolution.route(DownloadRoute());
      }),
    );
    final waiting = dispatcher.openUri(Uri.parse('prism://downloads'), source: DeepLinkSourceValue.inApp);
    const referral = ReferLinkIntent(inviterId: 'creator', rawUri: '/refer/creator');
    final referred = dispatcher.openAction(referral, source: DeepLinkSourceValue.appLinks);
    await tester.pump();
    expect(saved, isEmpty);
    bootstrap.complete(true);
    await tester.pump();
    expect(saved, <DeepLinkActionEntity>[referral]);
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(await waiting, DeepLinkDispatchResult.navigated);
    expect(await referred, DeepLinkDispatchResult.navigated);
    expect(saved.whereType<ReferLinkIntent>(), hasLength(1));
  });

  testWidgets('a cold push is received immediately and has one cancelled outcome if startup is disposed', (
    tester,
  ) async {
    await mount(tester);
    dispatcher.dispose();
    dispatcher = create(whenReady: () => Completer<bool>().future);
    final result = dispatcher.openPush(<String, dynamic>{'route': 'announcement'});
    await tester.pump();
    expect(events.whereType<DeepLinkReceivedEvent>().single.source, DeepLinkSourceValue.push);
    dispatcher.dispose();
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.cancelled);
    expect(results(), hasLength(1));
    expect(results().single.result, EventResultValue.cancelled);
  });

  testWidgets('legacy push receipt classifies valid payloads before asynchronous destination lookup', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    dispatcher = create(whenReady: () => Completer<bool>().future);
    final requests = <Future<DeepLinkDispatchResult>>[
      dispatcher.openPush(<String, dynamic>{'route': '/downloads'}),
      dispatcher.openPush(<String, dynamic>{'route': 'wall', 'wall_id': 'wall-1'}),
      dispatcher.openPush(<String, dynamic>{'route': 'follower', 'follower_uid': 'creator_uid'}),
    ];
    await tester.pump();
    final receipts = events.whereType<DeepLinkReceivedEvent>().toList();
    expect(receipts.map((event) => event.targetType), <TargetTypeValue>[
      TargetTypeValue.screen,
      TargetTypeValue.share,
      TargetTypeValue.user,
    ]);
    expect(receipts.map((event) => event.hasPayload), everyElement(isTrue));
    expect(events.whereType<DeepLinkResolvedEvent>(), isEmpty);
    dispatcher.dispose();
    await tester.pumpAndSettle();
    expect(await Future.wait(requests), everyElement(DeepLinkDispatchResult.cancelled));
  });

  testWidgets('logout cancels queued and in-flight resolution without opening stale targets', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    final pending = Completer<DeepLinkRouteResolution>();
    dispatcher = create(navigation: _ResolvingNavigation((_) => pending.future));
    final first = dispatcher.openUri(Uri.parse('prism://downloads'), source: DeepLinkSourceValue.appLinks);
    final second = dispatcher.openUri(Uri.parse('prism://about'), source: DeepLinkSourceValue.push);
    await tester.pump();
    dispatcher.cancel();
    await tester.pumpAndSettle();
    expect(await first, DeepLinkDispatchResult.cancelled);
    expect(await second, DeepLinkDispatchResult.cancelled);
    pending.complete(const DeepLinkRouteResolution.route(DownloadRoute()));
    await tester.pumpAndSettle();
    expect(router.topRoute.name, HomeTabRoute.name);
    expect(results(), hasLength(2));
    expect(results().map((event) => event.result), everyElement(EventResultValue.cancelled));
  });

  testWidgets('nested tab links activate their exact visible leaf', (tester) async {
    await mount(tester);
    for (final (path, name) in <(String, String)>[
      ('/dashboard/search/users', UserSearchRoute.name),
      ('/dashboard/rewards', RewardsTabRoute.name),
      ('/dashboard/home', HomeTabRoute.name),
    ]) {
      final result = dispatcher.openUri(Uri.parse('https://prismwalls.com$path'), source: DeepLinkSourceValue.inApp);
      await tester.pumpAndSettle();
      expect(await result, DeepLinkDispatchResult.navigated, reason: path);
      expect(router.topRoute.name, name, reason: path);
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('a denied route reports blocked once and never navigated', (tester) async {
    await mount(tester);
    final result = dispatcher.openUri(Uri.parse('prism://shop'), source: DeepLinkSourceValue.push);
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.blocked);
    expect(router.topRoute.name, HomeTabRoute.name);
    expect(results(), hasLength(1));
    expect(results().single.result, EventResultValue.blocked);
  });

  testWidgets('malformed direct links report failure while displaying not-found', (tester) async {
    await mount(tester);
    for (final link in <String>['https://prismwalls.com/user/%FF', 'prism://user/%FF', 'prism://%FF/alice']) {
      final result = dispatcher.openUri(Uri.parse(link), source: DeepLinkSourceValue.inApp);
      await tester.pumpAndSettle();
      expect(await result, DeepLinkDispatchResult.failure);
      expect(router.topRoute.name, NotFoundRoute.name);
    }
    expect(
      events.whereType<DeepLinkResolvedEvent>().map((event) => event.result),
      everyElement(EventResultValue.failure),
    );
    expect(results().map((event) => event.result), everyElement(EventResultValue.failure));
    expect(results().map((event) => event.targetType), everyElement(TargetTypeValue.unknown));
  });

  testWidgets('a malformed push URL still opens its legacy metadata destination', (tester) async {
    await mount(tester);
    final result = dispatcher.openPush(<String, dynamic>{'url': 'https://prismwalls.com/user/%FF', 'route': 'rewards'});
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, RewardsTabRoute.name);
    expect(results().single.source, DeepLinkSourceValue.push);
    expect(results().single.result, EventResultValue.navigated);
  });

  testWidgets('the platform transformer preserves malformed failure and explicit not-found success', (tester) async {
    dispatcher.dispose();
    dispatcher = create();
    final config = router.config(
      deepLinkTransformer: (uri) async => const DeepLinkParser().transform(uri),
      deepLinkBuilder: (link) {
        if (link.initial) return DeepLink.defaultPath;
        unawaited(dispatcher.openUri(link.uri, source: DeepLinkSourceValue.appLinks));
        return DeepLink.none;
      },
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    for (final (link, expected) in <(String, EventResultValue)>[
      ('https://prismwalls.com/user/%FF', EventResultValue.failure),
      ('prism://l?code=%FF', EventResultValue.failure),
      ('prism://%FF/alice', EventResultValue.failure),
      ('https://prismwalls.com/not-found', EventResultValue.navigated),
    ]) {
      final state = await config.routeInformationParser!.parseRouteInformation(RouteInformation(uri: Uri.parse(link)));
      await config.routerDelegate.setNewRoutePath(state);
      await tester.pumpAndSettle();
      expect(router.topRoute.name, NotFoundRoute.name, reason: link);
      expect(results().last.result, expected, reason: link);
      expect(results().last.source, DeepLinkSourceValue.appLinks);
    }
    expect(results(), hasLength(4));
  });

  testWidgets('a short-link retry keeps the source and emits one terminal navigation result', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    var attempts = 0;
    (ShortCodeIntent, DeepLinkSourceValue)? retry;
    dispatcher = DeepLinkDispatcher(
      router: router,
      whenReady: () async => true,
      navigation: _ResolvingNavigation((_) async {
        attempts++;
        return attempts == 1
            ? const DeepLinkRouteResolution.failure(AnalyticsReasonValue.error, isNetwork: true)
            : const DeepLinkRouteResolution.route(DownloadRoute());
      }),
      onRetryNeeded: (action, source) => retry = (action, source),
      track: (event) async => events.add(event),
    );
    final first = dispatcher.openUri(Uri.parse('prism://l/code'), source: DeepLinkSourceValue.push);
    await tester.pumpAndSettle();
    expect(await first, DeepLinkDispatchResult.deferred);
    expect(results(), isEmpty);
    final second = dispatcher.openAction(retry!.$1, source: retry!.$2, isRetry: true);
    await tester.pumpAndSettle();
    expect(await second, DeepLinkDispatchResult.navigated);
    expect(events.whereType<DeepLinkReceivedEvent>(), hasLength(1));
    expect(events.whereType<DeepLinkResolvedEvent>(), hasLength(2));
    expect(results(), hasLength(1));
    expect(results().single.source, DeepLinkSourceValue.push);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('logout gives deferred network requests a cancelled terminal result', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    dispatcher = DeepLinkDispatcher(
      router: router,
      whenReady: () async => true,
      navigation: _ResolvingNavigation(
        (_) async => const DeepLinkRouteResolution.failure(AnalyticsReasonValue.error, isNetwork: true),
      ),
      onRetryNeeded: (_, _) {},
      track: (event) async => events.add(event),
    );
    final result = dispatcher.openUri(Uri.parse('prism://l/code'), source: DeepLinkSourceValue.inApp);
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.deferred);
    dispatcher.cancel();
    await tester.pump();
    expect(results(), hasLength(1));
    expect(results().single.result, EventResultValue.cancelled);
    dispatcher.dispose();
    await tester.pump();
    expect(results(), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('unknown push target opens the inbox but reports the requested navigation failed', (tester) async {
    await mount(tester);
    final result = dispatcher.openUri(Uri.parse('prism://unknown/path'), source: DeepLinkSourceValue.push);
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.failure);
    expect(router.topRoute.name, NotificationRoute.name);
    expect(results().single.result, EventResultValue.failure);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('dispose cancels startup waiting and unregisters the old router dispatcher', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    dispatcher = create(whenReady: () => Completer<bool>().future);
    final result = dispatcher.openUri(Uri.parse('prism://downloads'), source: DeepLinkSourceValue.inApp);
    await tester.pump();
    dispatcher.dispose();
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.cancelled);
    expect(DeepLinkDispatcher.maybeOf(router), isNull);
    expect(results().single.result, EventResultValue.cancelled);
  });
}
