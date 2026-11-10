import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_catalog_resolver.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/deep_link_startup_gate.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/daily_flow/daily_moment_presentation_gate.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/share_in/domain/shared_item.dart';
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
    AutoRoute(path: '/gallery', page: _page(GalleryRoute.name)),
    AutoRoute(path: '/about', page: _page(AboutRoute.name)),
    AutoRoute(path: '/rewards', page: _page(RewardsRoute.name)),
    AutoRoute(path: '/wallpaper-detail', page: _page(WallpaperDetailRoute.name)),
    AutoRoute(path: '/followers', page: _page(FollowersRoute.name)),
    AutoRoute(path: '/following', page: _page(FollowingListRoute.name)),
    AutoRoute(path: '/share-in', page: _page(ShareInRoute.name)),
    AutoRoute(path: '/notifications', page: _page(NotificationRoute.name)),
    AutoRoute(path: '/shop', page: _page(ShopRoute.name), guards: <AutoRouteGuard>[_DenyGuard()]),
    AutoRoute(path: '/not-found', page: _page(NotFoundRoute.name)),
  ];

  static PageInfo _page(String name) => PageInfo(name, builder: (_) => Text(name));
}

class _RelationTestRouter extends _LinkTestRouter {
  @override
  List<AutoRouteGuard> get guards => const <AutoRouteGuard>[PlatformAccountGuard()];
}

class _ResolvingNavigation extends DeepLinkNavigation {
  const _ResolvingNavigation(this.resolve);

  final Future<DeepLinkRouteResolution> Function(DeepLinkActionEntity action) resolve;

  @override
  Future<DeepLinkRouteResolution> resolveAction(DeepLinkActionEntity action, {Future<bool> Function()? authenticate}) =>
      resolve(action);
}

class _RelationNavigation extends DeepLinkNavigation {
  const _RelationNavigation(this.profileLookup);

  final Future<PublicProfileEntity?> Function(String identifier) profileLookup;

  @override
  Future<PageRouteInfo?> mapActionToRoute(DeepLinkActionEntity action, {Future<bool> Function()? authenticate}) =>
      switch (action) {
        PageLinkIntent() => routeForPageLink(action, authenticate: authenticate, profileLookup: profileLookup),
        _ => super.mapActionToRoute(action, authenticate: authenticate),
      };
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

  Future<void> mountRelation(WidgetTester tester) async {
    app_state.prismUser.loggedIn = true;
    router = _RelationTestRouter();
    await mount(tester);
    unawaited(router.replaceAll(<PageRouteInfo>[AboutRoute()]));
    await tester.pumpAndSettle();
    app_state.prismUser = createGuestPrismUser();
  }

  List<DeepLinkNavigationResultEvent> results() => events.whereType<DeepLinkNavigationResultEvent>().toList();

  testWidgets('daily moment waits through link resolution and releases after leaving its target', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    final resolution = Completer<DeepLinkRouteResolution>();
    dispatcher = create(navigation: _ResolvingNavigation((_) => resolution.future));
    final opened = dispatcher.openUri(Uri.parse('/downloads'), source: DeepLinkSourceValue.appLinks);
    await tester.pump();
    expect(DailyMomentPresentationGate.instance.deepLinkActive, isTrue);
    resolution.complete(const DeepLinkRouteResolution.route(DownloadRoute()));
    await tester.pumpAndSettle();
    expect(await opened, DeepLinkDispatchResult.navigated);
    expect(DailyMomentPresentationGate.instance.deepLinkActive, isTrue);
    expect(router.stackData.map((route) => route.name), contains(DownloadRoute.name));
    expect(await router.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(router.stackData.map((route) => route.name), isNot(contains(DownloadRoute.name)));
    expect(DailyMomentPresentationGate.instance.deepLinkActive, isFalse);
  });

  testWidgets('a blocked link releases daily moment suppression', (tester) async {
    await mount(tester);
    final opened = dispatcher.openUri(Uri.parse('/shop'), source: DeepLinkSourceValue.appLinks);
    await tester.pumpAndSettle();
    expect(await opened, DeepLinkDispatchResult.blocked);
    expect(DailyMomentPresentationGate.instance.deepLinkActive, isFalse);
  });

  for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
    for (final (String path, String routeName) in <(String, String)>[
      ('/user/alice/followers', FollowersRoute.name),
      ('/user/alice/following', FollowingListRoute.name),
    ]) {
      testWidgets('guest $path link on $platform authenticates before lookup and passes the route guard', (
        tester,
      ) async {
        await mountRelation(tester);
        final continuation = AuthNavigationContinuation.of(router);
        continuation.markBootstrapCompleted();
        final List<String> calls = <String>[];
        dispatcher.dispose();
        dispatcher = create(
          navigation: _RelationNavigation((identifier) async {
            calls.add('lookup:$identifier');
            return const PublicProfileEntity(
              id: 'user-42',
              name: 'Alice',
              email: '',
              username: 'alice',
              profilePhoto: '',
              bio: '',
              links: <String, String>{},
              coverPhoto: '',
            );
          }),
        );
        addTearDown(continuation.dispose);

        final Future<DeepLinkDispatchResult> opened = dispatcher.openUri(
          Uri.parse(path),
          source: DeepLinkSourceValue.appLinks,
        );
        await tester.pumpAndSettle();
        expect(router.current.name, OnboardingV2ShellRoute.name);
        expect(calls, isEmpty, reason: 'username resolution must wait for authentication');

        app_state.prismUser.loggedIn = true;
        unawaited(router.replaceAll(const <PageRouteInfo>[SplashWidgetRoute()]));
        await tester.pumpAndSettle();
        unawaited(router.replaceAll(const <PageRouteInfo>[DashboardRoute()]));
        await tester.pumpAndSettle();

        expect(await opened, DeepLinkDispatchResult.navigated);
        expect(calls, <String>['lookup:alice']);
        expect(router.current.name, routeName);
        expect(
          router.current.args,
          routeName == FollowersRoute.name
              ? const FollowersRouteArgs(userId: 'user-42')
              : const FollowingListRouteArgs(userId: 'user-42'),
        );
      }, variant: TargetPlatformVariant({platform}));
    }
  }

  testWidgets('back from relation sign-in cancels without lookup or NotFound navigation', (tester) async {
    await mountRelation(tester);
    final continuation = AuthNavigationContinuation.of(router);
    continuation.markBootstrapCompleted();
    int lookups = 0;
    dispatcher.dispose();
    dispatcher = create(
      navigation: _RelationNavigation((_) async {
        lookups++;
        return null;
      }),
    );
    addTearDown(continuation.dispose);

    final Future<DeepLinkDispatchResult> opened = dispatcher.openUri(
      Uri.parse('/user/alice/following'),
      source: DeepLinkSourceValue.appLinks,
    );
    await tester.pumpAndSettle();
    expect(router.current.name, OnboardingV2ShellRoute.name);

    await router.maybePop();
    await tester.pumpAndSettle();

    expect(await opened, DeepLinkDispatchResult.cancelled);
    expect(lookups, 0);
    expect(router.stackData.map((route) => route.name), isNot(contains(NotFoundRoute.name)));
  });

  testWidgets('dispatcher cancellation before sign-in opens no stale onboarding', (tester) async {
    await mountRelation(tester);
    final continuation = AuthNavigationContinuation.of(router);
    continuation.markBootstrapCompleted();
    int lookups = 0;
    dispatcher.dispose();
    dispatcher = create(
      navigation: _RelationNavigation((_) async {
        lookups++;
        return null;
      }),
    );
    addTearDown(continuation.dispose);

    final Future<DeepLinkDispatchResult> opened = dispatcher.openUri(
      Uri.parse('/user/alice/followers'),
      source: DeepLinkSourceValue.appLinks,
    );
    await tester.idle();
    dispatcher.cancel();
    await tester.pumpAndSettle();

    expect(await opened, DeepLinkDispatchResult.cancelled);
    expect(router.current.name, AboutRoute.name);
    expect(lookups, 0);
  });

  testWidgets('cancellation during a late profile lookup cannot navigate its result', (tester) async {
    await mountRelation(tester);
    final continuation = AuthNavigationContinuation.of(router);
    continuation.markBootstrapCompleted();
    final Completer<PublicProfileEntity?> profile = Completer<PublicProfileEntity?>();
    final Completer<void> lookupStarted = Completer<void>();
    dispatcher.dispose();
    dispatcher = create(
      navigation: _RelationNavigation((_) {
        if (!lookupStarted.isCompleted) lookupStarted.complete();
        return profile.future;
      }),
    );
    addTearDown(continuation.dispose);

    final Future<DeepLinkDispatchResult> opened = dispatcher.openUri(
      Uri.parse('/user/alice/followers'),
      source: DeepLinkSourceValue.appLinks,
    );
    await tester.pumpAndSettle();
    expect(router.current.name, OnboardingV2ShellRoute.name);

    app_state.prismUser.loggedIn = true;
    unawaited(router.replaceAll(const <PageRouteInfo>[SplashWidgetRoute()]));
    await tester.pumpAndSettle();
    unawaited(router.replaceAll(const <PageRouteInfo>[DashboardRoute()]));
    await tester.pumpAndSettle();
    await lookupStarted.future;
    dispatcher.cancel();
    expect(await opened, DeepLinkDispatchResult.cancelled);

    profile.complete(
      const PublicProfileEntity(
        id: 'user-42',
        name: 'Alice',
        email: '',
        username: 'alice',
        profilePhoto: '',
        bio: '',
        links: <String, String>{},
        coverPhoto: '',
      ),
    );
    await tester.pumpAndSettle();

    expect(router.current.name, DashboardRoute.name);
    expect(router.stackData.map((route) => route.name), isNot(contains(FollowersRoute.name)));
    expect(router.stackData.map((route) => route.name), isNot(contains(NotFoundRoute.name)));
  });

  testWidgets('duplicate image delivery resolves only once, including after its sheet closes', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    int resolutions = 0;
    final Completer<bool> ready = Completer<bool>();
    dispatcher = create(
      whenReady: () => ready.future,
      navigation: _ResolvingNavigation((_) async {
        resolutions++;
        return DeepLinkRouteResolution.route(ShareInRoute(kind: SharedItemKind.image));
      }),
    );
    const ShareInIntent image = ShareInIntent(inboxId: 'one-image', rawUri: 'prism://share-in?id=one-image');

    final first = dispatcher.openAction(image, source: DeepLinkSourceValue.appLinks);
    final duplicate = dispatcher.openAction(image, source: DeepLinkSourceValue.appLinks);
    await tester.pump();
    expect(resolutions, 0, reason: 'the shared image waits for onboarding or sign-in');
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(await first, DeepLinkDispatchResult.navigated);
    expect(await duplicate, DeepLinkDispatchResult.navigated);
    expect(resolutions, 1);

    await router.maybePop();
    await tester.pumpAndSettle();
    expect(await dispatcher.openAction(image, source: DeepLinkSourceValue.appLinks), DeepLinkDispatchResult.navigated);
    expect(resolutions, 1);
    expect(router.topRoute.name, HomeTabRoute.name);
  });

  testWidgets('a text shared again after a different image resolves again', (tester) async {
    await mount(tester);
    dispatcher.dispose();
    int resolutions = 0;
    dispatcher = create(
      navigation: _ResolvingNavigation((_) async {
        resolutions++;
        return DeepLinkRouteResolution.route(ShareInRoute(key: UniqueKey(), kind: SharedItemKind.url));
      }),
    );
    const ShareInIntent text = ShareInIntent(text: 'https://example.com/a', rawUri: 'prism://share-in?text=a');
    const ShareInIntent image = ShareInIntent(inboxId: 'image-b', rawUri: 'prism://share-in?id=image-b');
    for (final ShareInIntent action in <ShareInIntent>[text, image, text]) {
      final result = dispatcher.openAction(action, source: DeepLinkSourceValue.appLinks);
      await tester.pumpAndSettle();
      expect(await result, DeepLinkDispatchResult.navigated);
    }
    expect(resolutions, 3);
  });

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

  testWidgets('id-only share URLs and pushes navigate with their own route args and success analytics', (tester) async {
    await mount(tester);
    final Future<DeepLinkDispatchResult> urlResult = dispatcher.openUri(
      Uri.parse('https://prismwalls.com/share?id=url-wall&provider=Wallhaven'),
      source: DeepLinkSourceValue.appLinks,
    );

    await tester.pumpAndSettle();

    expect(await urlResult, DeepLinkDispatchResult.navigated);
    final WallpaperDetailRouteArgs urlArgs = router.topRoute.argsAs<WallpaperDetailRouteArgs>();
    expect(urlArgs.wallId, 'url-wall');
    expect(urlArgs.source, WallpaperSource.wallhaven);
    expect(urlArgs.thumbnailUrl, isEmpty);
    expect(urlArgs.analyticsSurface, AnalyticsSurfaceValue.shareWallpaperView);
    expect(urlArgs.entity, isNull);
    expect(urlArgs.localFile, isNull);

    final Future<DeepLinkDispatchResult> pushResult = dispatcher.openPush(<String, dynamic>{
      'url': 'https://prismwalls.com/share?id=push-wall&provider=Pexels',
    });

    await tester.pumpAndSettle();

    expect(await pushResult, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, WallpaperDetailRoute.name);
    final WallpaperDetailRouteArgs args = router.topRoute.argsAs<WallpaperDetailRouteArgs>();
    expect(args.wallId, 'push-wall');
    expect(args.source, WallpaperSource.pexels);
    expect(args.thumbnailUrl, isEmpty);
    expect(args.analyticsSurface, AnalyticsSurfaceValue.shareWallpaperView);
    expect(args.entity, isNull);
    expect(args.localFile, isNull);

    final List<DeepLinkReceivedEvent> received = events.whereType<DeepLinkReceivedEvent>().toList();
    expect(received.map((event) => event.source), <DeepLinkSourceValue>[
      DeepLinkSourceValue.appLinks,
      DeepLinkSourceValue.push,
    ]);
    expect(received.map((event) => event.targetType), everyElement(TargetTypeValue.share));
    final List<DeepLinkResolvedEvent> resolved = events.whereType<DeepLinkResolvedEvent>().toList();
    expect(resolved.map((event) => event.targetType), everyElement(TargetTypeValue.share));
    expect(resolved.map((event) => event.result), everyElement(EventResultValue.success));
    expect(results().map((event) => event.targetType), everyElement(TargetTypeValue.share));
    expect(results().map((event) => event.result), everyElement(EventResultValue.navigated));
  });

  testWidgets('a protected Wall of the Day tile waits for startup and opens its document with no original URL', (
    tester,
  ) async {
    await mount(tester);
    final Completer<bool> ready = Completer<bool>();
    dispatcher.dispose();
    dispatcher = create(whenReady: () => ready.future);
    const String thumbnail = 'https://example.com/thumb.jpg?width=320&height=240';
    final Uri link = Uri(
      scheme: 'prism',
      host: 'share',
      queryParameters: <String, String>{'id': 'protected-document', 'source': 'prism', 'url': '', 'thumb': thumbnail},
    );

    final Future<DeepLinkDispatchResult> result = dispatcher.openUri(
      const DeepLinkParser().transform(Uri.parse(link.toString())),
      source: DeepLinkSourceValue.appLinks,
    );
    await tester.pumpAndSettle();
    expect(router.topRoute.name, HomeTabRoute.name);

    ready.complete(true);
    await tester.pumpAndSettle();

    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, WallpaperDetailRoute.name);
    final WallpaperDetailRouteArgs args = router.topRoute.argsAs<WallpaperDetailRouteArgs>();
    expect(args.wallId, 'protected-document');
    expect(args.source, WallpaperSource.prism);
    expect(args.thumbnailUrl, thumbnail);
    expect(args.analyticsSurface, AnalyticsSurfaceValue.shareWallpaperView);
    expect(args.entity, isNull);
    expect(args.localFile, isNull);
    expect(events.whereType<DeepLinkReceivedEvent>().single.targetType, TargetTypeValue.share);
    expect(results().single.result, EventResultValue.navigated);
  });

  testWidgets('a gallery push opens the gallery page before its fallback wall link', (tester) async {
    await mount(tester);
    final Future<DeepLinkDispatchResult> result = dispatcher.openPush(<String, dynamic>{
      'route': 'wall_of_the_day',
      'wall_id': 'lead-doc',
      'url': 'https://prismwalls.com/share?id=lead&provider=Prism',
      'wall_ids': 'W1,W2,W3',
      'gallery': '1',
    });

    await tester.pumpAndSettle();

    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, GalleryRoute.name);
    final GalleryRouteArgs args = router.topRoute.argsAs<GalleryRouteArgs>();
    expect(args.ids, 'W1,W2,W3');
    expect(args.source, 'push');
  });

  testWidgets('a push with one wall id keeps its wall link', (tester) async {
    await mount(tester);
    final Future<DeepLinkDispatchResult> result = dispatcher.openPush(<String, dynamic>{
      'url': 'https://prismwalls.com/share?id=lead&provider=Prism',
      'wall_ids': 'W1',
    });

    await tester.pumpAndSettle();

    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, WallpaperDetailRoute.name);
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

  testWidgets('an onboarding link after guest replacement opens a fresh shell', (tester) async {
    await mount(tester);
    unawaited(router.replaceAll(<PageRouteInfo>[OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    final firstSignIn = tester.element(find.text(OnboardingV2ShellRoute.name));
    late Future<DeepLinkDispatchResult> result;

    unawaited(
      router.replaceAll(const <PageRouteInfo>[DashboardRoute()]).then((_) {
        result = dispatcher.openUri(Uri.parse('prism://onboarding/v2'), source: DeepLinkSourceValue.appLinks);
      }),
    );
    await tester.pumpAndSettle();

    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, OnboardingV2ShellRoute.name);
    expect(firstSignIn.mounted, isFalse, reason: 'a finished onboarding shell must not be reused');
  });

  testWidgets('an onboarding link adopts a shell opened while waiting for its frame', (tester) async {
    await mount(tester);
    final result = dispatcher.openUri(Uri.parse('prism://onboarding/v2'), source: DeepLinkSourceValue.appLinks);
    await tester.idle();
    unawaited(router.push(OnboardingV2ShellRoute()));
    await tester.pumpAndSettle();

    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), hasLength(1));
    expect(find.text(OnboardingV2ShellRoute.name), findsOneWidget);
  });

  for (final dispose in [false, true]) {
    testWidgets('${dispose ? 'disposing' : 'cancelling'} an onboarding link before its frame prevents navigation', (
      tester,
    ) async {
      await mount(tester);
      final result = dispatcher.openUri(Uri.parse('prism://onboarding/v2'), source: DeepLinkSourceValue.appLinks);
      await tester.idle();
      expect(router.topRoute.name, HomeTabRoute.name);

      if (dispose) {
        dispatcher.dispose();
      } else {
        dispatcher.cancel();
      }
      expect(await result, DeepLinkDispatchResult.cancelled);
      await tester.pumpAndSettle();

      expect(router.topRoute.name, HomeTabRoute.name);
      expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
    });
  }

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

  testWidgets('a widget link records widget_tapped and still records deep_link_received', (tester) async {
    await mount(tester);
    final result = dispatcher.openUri(
      Uri.parse('prism://share?id=abc&source=prism&thumb=https%3A%2F%2Fexample.com%2Ft.jpg&widget=wotd_medium'),
      source: DeepLinkSourceValue.appLinks,
    );
    await tester.pumpAndSettle();
    await result;
    expect(events.whereType<WidgetTappedEvent>().map((event) => event.kind), <WidgetKindValue>[
      WidgetKindValue.wotdMedium,
    ]);
    expect(events.whereType<DeepLinkReceivedEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a share link without a widget parameter records no widget_tapped', (tester) async {
    await mount(tester);
    final result = dispatcher.openUri(
      Uri.parse('prism://share?id=abc&source=prism&thumb=https%3A%2F%2Fexample.com%2Ft.jpg'),
      source: DeepLinkSourceValue.appLinks,
    );
    await tester.pumpAndSettle();
    await result;
    expect(events.whereType<WidgetTappedEvent>(), isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('an unknown widget value records no widget_tapped', (tester) async {
    await mount(tester);
    final result = dispatcher.openUri(Uri.parse('prism://streak?widget=nope'), source: DeepLinkSourceValue.appLinks);
    await tester.pumpAndSettle();
    await result;
    expect(events.whereType<WidgetTappedEvent>(), isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a streak widget link opens Rewards and records its widget kind', (tester) async {
    await mount(tester);
    final result = dispatcher.openUri(
      const DeepLinkParser().transform(Uri.parse('prism://streak?widget=streak_circular')),
      source: DeepLinkSourceValue.appLinks,
    );
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, RewardsRoute.name);
    expect(events.whereType<WidgetTappedEvent>().map((event) => event.kind), <WidgetKindValue>[
      WidgetKindValue.streakCircular,
    ]);
  });

  testWidgets('an empty Wall of the Day widget fallback opens Rewards and records its Wall of the Day kind', (
    tester,
  ) async {
    await mount(tester);
    final result = dispatcher.openUri(
      const DeepLinkParser().transform(Uri.parse('prism://streak?widget=wotd_small')),
      source: DeepLinkSourceValue.appLinks,
    );
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, RewardsRoute.name);
    expect(events.whereType<WidgetTappedEvent>().map((event) => event.kind), <WidgetKindValue>[
      WidgetKindValue.wotdSmall,
    ]);
  });

  testWidgets('a transformed Wall of the Day widget share opens its wall and thumbnail', (tester) async {
    await mount(tester);
    const String thumbnail = 'https://example.com/thumb.jpg?width=320&height=240';
    final Uri link = Uri(
      scheme: 'prism',
      host: 'share',
      queryParameters: <String, String>{
        'id': 'wall-document-field-id',
        'source': 'prism',
        'thumb': thumbnail,
        'widget': 'wotd_medium',
      },
    );
    final Uri transformedLink = const DeepLinkParser().transform(link);
    final result = dispatcher.openUri(transformedLink, source: DeepLinkSourceValue.appLinks);
    await tester.pumpAndSettle();
    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.topRoute.name, WallpaperDetailRoute.name);
    final WallpaperDetailRouteArgs args = router.topRoute.argsAs<WallpaperDetailRouteArgs>();
    expect(args.wallId, 'wall-document-field-id');
    expect(args.thumbnailUrl, thumbnail);
    expect(events.whereType<WidgetTappedEvent>().map((event) => event.kind), <WidgetKindValue>[
      WidgetKindValue.wotdMedium,
    ]);
  });

  testWidgets('widget taps are tracked once while cold and once for each warm tap', (tester) async {
    await mount(tester);
    final Completer<bool> ready = Completer<bool>();
    dispatcher.dispose();
    dispatcher = create(whenReady: () => ready.future);
    final Uri streakLink = const DeepLinkParser().transform(Uri.parse('prism://streak?widget=streak_inline'));

    final Future<DeepLinkDispatchResult> coldTap = dispatcher.openUri(streakLink, source: DeepLinkSourceValue.appLinks);
    expect(events.whereType<WidgetTappedEvent>().map((event) => event.kind), <WidgetKindValue>[
      WidgetKindValue.streakInline,
    ]);
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(await coldTap, DeepLinkDispatchResult.navigated);
    expect(events.whereType<WidgetTappedEvent>(), hasLength(1));

    final Future<DeepLinkDispatchResult> warmTap = dispatcher.openUri(streakLink, source: DeepLinkSourceValue.appLinks);
    await tester.pumpAndSettle();
    expect(await warmTap, DeepLinkDispatchResult.navigated);
    expect(events.whereType<WidgetTappedEvent>().map((event) => event.kind), <WidgetKindValue>[
      WidgetKindValue.streakInline,
      WidgetKindValue.streakInline,
    ]);
  });

  testWidgets('widget analytics only records valid widget links received from app links', (tester) async {
    await mount(tester);
    for (final (Uri uri, DeepLinkSourceValue source) in <(Uri, DeepLinkSourceValue)>[
      (const DeepLinkParser().transform(Uri.parse('prism://about?widget=wotd_small')), DeepLinkSourceValue.appLinks),
      (
        const DeepLinkParser().transform(
          Uri.parse('prism://share?id=abc&source=prism&thumb=https%3A%2F%2Fexample.com%2Ft.jpg&widget=wotd_small'),
        ),
        DeepLinkSourceValue.inApp,
      ),
      (
        const DeepLinkParser().transform(Uri.parse('prism://streak?widget=streak_inline&other=value')),
        DeepLinkSourceValue.appLinks,
      ),
    ]) {
      final result = dispatcher.openUri(uri, source: source);
      await tester.pumpAndSettle();
      await result;
    }
    expect(events.whereType<WidgetTappedEvent>(), isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });
}
