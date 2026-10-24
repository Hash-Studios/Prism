import 'dart:async';

import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ValueKey<String> _tile(String page) => ValueKey('tile-$page');
ValueKey<String> _art(String page) => ValueKey('art-$page');
ValueKey<String> _marker(String page) => ValueKey('marker-$page');

class _StackRouter extends RootStackRouter {
  _StackRouter({this.nested = false});

  final bool nested;
  final pages = <String, _PageState>{};
  final routesByName = <String, ModalRoute<dynamic>>{};

  PageInfo _page(String name, {String? card, String? source, Rect? rect}) => PageInfo(
    name,
    builder: (_) => _Page(
      name: name,
      card: card,
      source: source,
      rect: rect ?? const Rect.fromLTWH(40, 120, 100, 140),
      onRoute: (route) => routesByName[name] = route,
      onState: (state) => pages[name] = state,
    ),
  );

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
    if (nested)
      AutoRoute(
        path: '/',
        page: PageInfo(
          'Shell',
          builder: (_) => const Padding(padding: EdgeInsets.fromLTRB(32, 48, 24, 16), child: AutoRouter()),
        ),
        children: [
          AutoRoute(
            path: '',
            page: _page('Grid', source: 'a'),
          ),
        ],
      )
    else
      AutoRoute(
        path: '/',
        page: _page('Grid', source: 'a'),
      ),
    AutoRoute(
      path: '/fullscreen',
      fullscreenDialog: true,
      page: _page('Fullscreen', source: 'a'),
    ),
    AutoRoute(
      path: '/replacement',
      page: _page('Replacement', source: 'a', rect: const Rect.fromLTWH(180, 240, 80, 110)),
    ),
    AutoRoute(
      path: '/empty',
      page: _page('Empty', source: 'a', rect: Rect.zero),
    ),
    CustomRoute(
      path: '/first',
      page: _page('First', card: 'a', source: 'b', rect: const Rect.fromLTWH(420, 400, 90, 120)),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
    CustomRoute(
      path: '/second',
      page: _page('Second', card: 'b'),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

class _Page extends StatefulWidget {
  const _Page({
    required this.name,
    this.card,
    this.source,
    required this.rect,
    required this.onRoute,
    required this.onState,
  });

  final String name;
  final String? card;
  final String? source;
  final Rect rect;
  final ValueChanged<ModalRoute<dynamic>> onRoute;
  final ValueChanged<_PageState> onState;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final scroll = ScrollController();
  int count = 0;

  @override
  void initState() {
    super.initState();
    widget.onState(this);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onRoute(ModalRoute.of(context)!);
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SingleChildScrollView(
        controller: scroll,
        child: SizedBox(
          height: 1400,
          child: Stack(
            children: [
              if (widget.card case final String tag)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 300,
                  child: WallpaperDetailHero(
                    tag: tag,
                    radius: 20,
                    image: ColoredBox(key: _art(widget.name), color: color),
                  ),
                ),
              if (widget.source case final String tag)
                Positioned.fromRect(
                  rect: widget.rect,
                  child: Hero(
                    tag: tag,
                    createRectTween: wallpaperHeroRectTween,
                    child: ColoredBox(key: _tile(widget.name), color: color),
                  ),
                ),
              Positioned(
                left: 200,
                top: 320,
                width: 100,
                height: 48,
                child: TextButton(
                  key: _marker(widget.name),
                  onPressed: () => setState(() => count++),
                  child: Text('${widget.name}: $count'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<_StackRouter> _pump(WidgetTester tester, {bool nested = false}) async {
  final router = _StackRouter(nested: nested);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _flight(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
}

void _expectLocked(
  WidgetTester tester, {
  required String below,
  required String above,
  required Rect tile,
  required Rect marker,
}) {
  final art = tester.getRect(find.byKey(_art(above)));
  final actual = tester.getRect(find.byKey(_marker(below)));
  final scale = art.width / tile.width;
  expect(actual.left, closeTo(art.left + (marker.left - tile.left) * scale, 0.1));
  expect(actual.top, closeTo(art.top + (marker.top - tile.top) * scale, 0.1));
  expect(actual.width, closeTo(marker.width * scale, 0.1));
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform recommendation detail delegates both ways and preserves prior detail state and scroll', (
      tester,
    ) async {
      final router = await _pump(tester);
      unawaited(router.push<void>(const PageRouteInfo<void>('First')));
      await tester.pumpAndSettle();
      final state = router.pages['First']!;
      await tester.tap(find.text('First: 0'));
      state.scroll.jumpTo(30);
      await tester.pump();
      final tile = tester.getRect(find.byKey(_tile('First')));
      final marker = tester.getRect(find.byKey(_marker('First')));
      unawaited(router.push<void>(const PageRouteInfo<void>('Second')));
      await _flight(tester);
      _expectLocked(tester, below: 'First', above: 'Second', tile: tile, marker: marker);
      await tester.pumpAndSettle();
      unawaited(router.maybePop<void>());
      await _flight(tester);
      _expectLocked(tester, below: 'First', above: 'Second', tile: tile, marker: marker);
      await tester.pumpAndSettle();
      expect(router.pages['First'], same(state));
      expect(state.scroll.offset, 30);
      expect(find.text('First: 1'), findsOneWidget);
      expect(tester.getRect(find.byKey(_tile('First'))), tile);
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform root detail measures an offset nested shell source in root coordinates', (tester) async {
      final router = await _pump(tester, nested: true);
      final state = router.pages['Grid']!;
      final tile = tester.getRect(find.byKey(_tile('Grid')));
      final marker = tester.getRect(find.byKey(_marker('Grid')));
      expect(tile.topLeft, const Offset(72, 168));
      unawaited(router.push<void>(const PageRouteInfo<void>('First')));
      await _flight(tester);
      _expectLocked(tester, below: 'Grid', above: 'First', tile: tile, marker: marker);
      await tester.pumpAndSettle();
      unawaited(router.maybePop<void>());
      await _flight(tester);
      _expectLocked(tester, below: 'Grid', above: 'First', tile: tile, marker: marker);
      await tester.pumpAndSettle();
      expect(router.pages['Grid'], same(state));
      expect(tester.getRect(find.byKey(_tile('Grid'))), tile);
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform previous native fullscreen dialog zooms and restores its source', (tester) async {
      final router = await _pump(tester);
      unawaited(router.push<void>(const PageRouteInfo<void>('Fullscreen')));
      await tester.pumpAndSettle();
      expect(
        router.routesByName['Fullscreen'],
        isA<PageRoute<dynamic>>().having((route) => route.fullscreenDialog, 'fullscreenDialog', isTrue),
      );
      final tile = tester.getRect(find.byKey(_tile('Fullscreen')));
      final marker = tester.getRect(find.byKey(_marker('Fullscreen')));
      unawaited(router.push<void>(const PageRouteInfo<void>('First')));
      await _flight(tester);
      _expectLocked(tester, below: 'Fullscreen', above: 'First', tile: tile, marker: marker);
      await tester.pumpAndSettle();
      unawaited(router.maybePop<void>());
      await _flight(tester);
      _expectLocked(tester, below: 'Fullscreen', above: 'First', tile: tile, marker: marker);
      await tester.pumpAndSettle();
      expect(router.current.name, 'Fullscreen');
      expect(tester.getRect(find.byKey(_tile('Fullscreen'))), tile);
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('replacing the route below remeasures the fresh pop destination', (tester) async {
    final router = await _pump(tester);
    unawaited(router.push<void>(const PageRouteInfo<void>('First')));
    await tester.pumpAndSettle();
    unawaited(router.insert(const PageRouteInfo<void>('Replacement')));
    await tester.pump();
    router.removeWhere((route) => route.name == 'Grid');
    await tester.pumpAndSettle();
    unawaited(router.maybePop<void>());
    await _flight(tester);
    _expectLocked(
      tester,
      below: 'Replacement',
      above: 'First',
      tile: const Rect.fromLTWH(180, 240, 80, 110),
      marker: const Rect.fromLTWH(200, 320, 100, 48),
    );
    await tester.pumpAndSettle();
    expect(router.current.name, 'Replacement');
    expect(tester.getRect(find.byKey(_tile('Replacement'))), const Rect.fromLTWH(180, 240, 80, 110));
  });

  testWidgets('repeated opens preserve grid state and an empty source never applies a stale zoom', (tester) async {
    final router = await _pump(tester);
    final state = router.pages['Grid']!;
    await tester.tap(find.text('Grid: 0'));
    state.scroll.jumpTo(20);
    await tester.pump();
    final tile = tester.getRect(find.byKey(_tile('Grid')));
    for (var i = 0; i < 3; i++) {
      unawaited(router.push<void>(const PageRouteInfo<void>('First')));
      await tester.pumpAndSettle();
      unawaited(router.maybePop<void>());
      await tester.pumpAndSettle();
      expect(router.pages['Grid'], same(state));
      expect(state.scroll.offset, 20);
      expect(find.text('Grid: 1'), findsOneWidget);
      expect(tester.getRect(find.byKey(_tile('Grid'))), tile);
    }
    unawaited(router.push<void>(const PageRouteInfo<void>('Empty')));
    await tester.pumpAndSettle();
    unawaited(router.push<void>(const PageRouteInfo<void>('First')));
    await _flight(tester);
    expect(tester.getRect(find.byKey(_marker('First'))), const Rect.fromLTWH(200, 320, 100, 48));
    expect(tester.getRect(find.byKey(_marker('Empty'))), const Rect.fromLTWH(200, 320, 100, 48));
    await tester.pumpAndSettle();
    unawaited(router.maybePop<void>());
    await tester.pumpAndSettle();
    expect(router.current.name, 'Empty');
  });
}
