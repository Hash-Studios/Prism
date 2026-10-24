import 'dart:async';
import 'dart:ui' as ui;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tileKey = ValueKey<String>('tile');
const _artKey = ValueKey<String>('detail-art');
const _bodyKey = ValueKey<String>('detail-body');
const _otherTileKey = ValueKey<String>('other-tile');
const _pictureTileKey = ValueKey<String>('picture-tile');
const _testZoomCurve = Cubic(0.45, 0.3, 0.1, 1);

int _tileDecodes = 0;

/// A grid tile's picture. It decodes once; the detail must paint that decode, not make its own.
class _TilePicture extends ImageProvider<_TilePicture> {
  const _TilePicture(this.image);

  final ui.Image image;

  @override
  Future<_TilePicture> obtainKey(ImageConfiguration configuration) => SynchronousFuture<_TilePicture>(this);

  @override
  ImageStreamCompleter loadImage(_TilePicture key, ImageDecoderCallback decode) {
    _tileDecodes++;
    return OneFrameImageStreamCompleter(SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())));
  }
}

class _TestRouter extends RootStackRouter {
  _TestRouter({this.allowPop = true, this.picture});

  final bool allowPop;
  final ImageProvider? picture;
  ModalRoute<dynamic>? detailRoute;

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Grid',
        builder: (_) => Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 40,
                top: 120,
                width: 100,
                height: 140,
                child: GestureDetector(
                  onTap: () => push(const PageRouteInfo<void>('Zoom')),
                  child: const Hero(
                    tag: 'wall',
                    createRectTween: wallpaperHeroRectTween,
                    child: ColoredBox(key: _tileKey, color: Colors.blue),
                  ),
                ),
              ),
              Positioned(
                left: 600,
                top: 400,
                width: 100,
                height: 140,
                child: GestureDetector(
                  onTap: () => push(const PageRouteInfo<void>('Lone')),
                  child: const ColoredBox(key: _otherTileKey, color: Colors.red),
                ),
              ),
              if (picture case final ImageProvider image)
                Positioned(
                  left: 200,
                  top: 120,
                  width: 100,
                  height: 140,
                  child: GestureDetector(
                    onTap: () => push(const PageRouteInfo<void>('Picture')),
                    child: Hero(
                      tag: 'picture',
                      child: Image(key: _pictureTileKey, image: image, fit: BoxFit.cover),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    CustomRoute(
      path: '/detail',
      page: PageInfo(
        'Detail',
        builder: (_) => Builder(
          builder: (context) {
            detailRoute = ModalRoute.of(context);
            return PopScope(
              canPop: allowPop,
              child: Scaffold(
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeroMode(
                      enabled: !context.reduceMotion,
                      child: const Hero(
                        tag: 'wall',
                        child: SizedBox(
                          height: 300,
                          child: ColoredBox(key: _artKey, color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(key: _bodyKey, height: 100, child: _Counter()),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
    for (final (name, tag) in [('Zoom', 'wall'), ('Lone', 'no-tile'), ('Picture', 'picture')])
      CustomRoute(
        path: '/${name.toLowerCase()}',
        page: PageInfo(
          name,
          builder: (_) => Builder(
            builder: (context) {
              detailRoute = ModalRoute.of(context);
              return PopScope(
                canPop: allowPop,
                child: Scaffold(
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 300,
                        child: HeroMode(
                          enabled: !context.reduceMotion,
                          child: WallpaperDetailHero(
                            tag: tag,
                            radius: 20,
                            image: const ColoredBox(key: _artKey, color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(key: _bodyKey, height: 100, child: _Counter()),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        customRouteBuilder: wallpaperDetailRouteBuilder,
      ),
  ];
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => count++), child: Text('count $count'));
}

Future<_TestRouter> _pumpRouter(
  WidgetTester tester, {
  bool reduceMotion = false,
  bool allowPop = true,
  ImageProvider? picture,
}) async {
  final router = _TestRouter(allowPop: allowPop, picture: picture);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router.config(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void _expectScrimAlpha(WidgetTester tester, _TestRouter router, {required bool reverse}) {
  final Animation<double> animation = router.detailRoute!.animation!;
  final Curve curve = reverse ? const FlippedCurve(_testZoomCurve) : _testZoomCurve;
  final double alpha = 0.3 * curve.transform(animation.value);
  final Finder body = find.byKey(_bodyKey);
  final Finder transition = find.ancestor(of: body, matching: find.byType(Stack)).first;
  final Finder ignorePointer = find.descendant(of: transition, matching: find.byType(IgnorePointer)).first;
  final ColoredBox scrim = tester.widget(find.descendant(of: ignorePointer, matching: find.byType(ColoredBox)).first);
  final Color expected = Theme.of(tester.element(body)).colorScheme.scrim.withValues(alpha: alpha);
  expect(scrim.color, expected);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform opens in place while its Hero expands, then returns a typed result', (tester) async {
      final router = await _pumpRouter(tester);
      final tile = tester.getRect(find.byKey(_tileKey));
      final result = router.push<int>(const PageRouteInfo<void>('Detail'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(tester.getRect(find.byKey(_artKey)).width, closeTo(tile.width, 1));
      expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
      expect(router.detailRoute!.transitionDuration, PrismDurations.fast);
      expect(router.detailRoute!.settings, same(router.stack.last));
      expect(router.current.animationCompletion, isNotNull);

      double lastWidth = tile.width;
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        final flying = tester.getRect(find.byKey(_artKey));
        expect(flying.width, greaterThan(lastWidth));
        expect(flying.width, lessThanOrEqualTo(800));
        expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
        final fade = tester.widget<FadeTransition>(
          find.ancestor(of: find.byKey(_bodyKey), matching: find.byType(FadeTransition)).first,
        );
        expect(fade.opacity.value, closeTo(PrismCurves.enter.transform(((i + 1) * 40 + 1) / 160), 0.001));
        lastWidth = flying.width;
      }
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_artKey)), const Rect.fromLTWH(0, 0, 800, 300));
      expect(router.current.animationCompletion, isNull);

      unawaited(router.maybePop<int>(7));
      await tester.pumpAndSettle();
      expect(await result, 7);
      expect(router.current.name, 'Grid');
      expect(tester.getRect(find.byKey(_tileKey)), tile);
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform reduced motion opens immediately without a Hero flight or fade', (tester) async {
      final router = await _pumpRouter(tester, reduceMotion: true);
      unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
      await tester.pump();
      await tester.pump();

      expect(router.detailRoute!.transitionDuration, Duration.zero);
      expect(router.detailRoute!.animation!.isCompleted, isTrue);
      expect(tester.getRect(find.byKey(_artKey)), const Rect.fromLTWH(0, 0, 800, 300));
      expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.byKey(_bodyKey), matching: find.byType(FadeTransition)),
      );
      expect(fades.every((fade) => fade.opacity.value == 1), isTrue);
      unawaited(router.maybePop<void>());
      await tester.pumpAndSettle();
      expect(router.current.name, 'Grid');
    }, variant: TargetPlatformVariant({platform}));
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform card Hero grows the whole page out of the tile, locked to the flying picture', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);
      final tile = tester.getRect(find.byKey(_tileKey));
      final result = router.push<int>(const PageRouteInfo<void>('Zoom'));
      // The page lays out offstage first so the Hero can measure the card. Nothing of it shows until the flight starts.
      for (var i = 0; i < 4 && find.byKey(_artKey).evaluate().isEmpty; i++) {
        expect(find.byKey(_bodyKey), findsNothing);
        await tester.pump();
      }

      // The picture starts as the tile itself and morphs into the card. The page is a small copy of itself that
      // follows the picture's left edge, top edge and width: its card slot starts under the picture and its body
      // starts where that slot ends, which is never below the picture.
      var frames = 0;
      var behindFrames = 0;
      while (router.detailRoute!.animation!.isAnimating) {
        final art = tester.getRect(find.byKey(_artKey));
        final body = tester.getRect(find.byKey(_bodyKey));
        if (frames == 0) {
          expect(art.left, closeTo(tile.left, 0.01));
          expect(art.top, closeTo(tile.top, 0.01));
          expect(art.size.width, closeTo(tile.width, 0.01));
          expect(art.size.height, closeTo(tile.height, 0.01), reason: 'no snap to the card shape on the first frame');
        }
        expect(body.left, closeTo(art.left, 0.01), reason: 'frame $frames');
        expect(body.width, closeTo(art.width, 0.01), reason: 'frame $frames');
        expect(body.top, closeTo(art.top + art.width * 300 / 800, 0.01), reason: 'frame $frames');
        expect(body.top, lessThanOrEqualTo(art.bottom + 0.01), reason: 'frame $frames');
        _expectScrimAlpha(tester, router, reverse: false);
        // The grid behind zooms with the card, so its other tile maps the same way as the tile does.
        if (find.byKey(_otherTileKey).evaluate().isNotEmpty) {
          final Rect other = tester.getRect(find.byKey(_otherTileKey));
          final double s = art.width / tile.width;
          expect(other.left, closeTo(art.left + (600 - tile.left) * s, 0.01), reason: 'frame $frames');
          expect(other.top, closeTo(art.top + (400 - tile.top) * s, 0.01), reason: 'frame $frames');
          expect(other.width, closeTo(100 * s, 0.01), reason: 'frame $frames');
          behindFrames++;
        }
        frames++;
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(frames, greaterThan(5));
      expect(behindFrames, greaterThan(3));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_artKey)), const Rect.fromLTWH(0, 0, 800, 300));
      expect(tester.getRect(find.byKey(_bodyKey)), const Rect.fromLTWH(0, 300, 800, 100));
      // The card flies on the curve measured from the reference closeup, set on the Hero itself.
      final Hero card = tester.widget<Hero>(
        find.descendant(of: find.byType(WallpaperDetailHero), matching: find.byType(Hero)),
      );
      expect(card.curve, const Cubic(0.45, 0.3, 0.1, 1));

      // Going back shrinks the page into its tile, and the grid behind zooms back out with it.
      unawaited(router.maybePop<int>(3));
      await tester.pump();
      var popFrames = 0;
      double lastWidth = 800;
      while (router.detailRoute!.animation!.isAnimating) {
        if (tester.getRect(find.byKey(_bodyKey)).width < 799) {
          final Rect art = tester.getRect(find.byKey(_artKey));
          final Rect body = tester.getRect(find.byKey(_bodyKey));
          expect(body.left, closeTo(art.left, 0.01), reason: 'pop frame $popFrames');
          expect(body.width, closeTo(art.width, 0.01), reason: 'pop frame $popFrames');
          expect(body.top, closeTo(art.top + art.width * 300 / 800, 0.01), reason: 'pop frame $popFrames');
          expect(body.width, lessThanOrEqualTo(lastWidth + 0.01), reason: 'pop frame $popFrames');
          _expectScrimAlpha(tester, router, reverse: true);
          lastWidth = body.width;
          if (find.byKey(_otherTileKey).evaluate().isNotEmpty) {
            final Rect other = tester.getRect(find.byKey(_otherTileKey));
            final double s = art.width / tile.width;
            expect(other.left, closeTo(art.left + (600 - tile.left) * s, 0.01), reason: 'pop frame $popFrames');
            expect(other.top, closeTo(art.top + (400 - tile.top) * s, 0.01), reason: 'pop frame $popFrames');
            expect(other.width, closeTo(100 * s, 0.01), reason: 'pop frame $popFrames');
          }
          popFrames++;
        }
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(popFrames, greaterThan(3));
      await tester.pumpAndSettle();
      expect(await result, 3);
      expect(router.current.name, 'Grid');
      expect(tester.getRect(find.byKey(_tileKey)), tile);
      expect(tester.getRect(find.byKey(_otherTileKey)), const Rect.fromLTWH(600, 400, 100, 140));
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform card flies and lands on the decoded picture of its tile, under its own picture', (
      tester,
    ) async {
      final ui.Image decoded = (await tester.runAsync(() => createTestImage(width: 10, height: 14)))!;
      final picture = _TilePicture(decoded);
      _tileDecodes = 0;
      final router = await _pumpRouter(tester, picture: picture);
      final tile = tester.getRect(find.byKey(_pictureTileKey));
      expect(_tileDecodes, 1);
      unawaited(router.push<void>(const PageRouteInfo<void>('Picture')));
      for (var i = 0; i < 4 && find.byKey(_artKey).evaluate().isEmpty; i++) {
        await tester.pump();
      }

      // The tile is offstage while its Hero flies, so the only picture on screen is the one under the card's own. It
      // paints from the first frame, at the tile's place.
      final Finder shown = find.byType(RawImage);
      var frames = 0;
      while (router.detailRoute!.animation!.isAnimating) {
        expect(tester.widget<RawImage>(shown).image!.isCloneOf(decoded), isTrue, reason: 'frame $frames');
        expect(tester.getRect(shown), tester.getRect(find.byKey(_artKey)), reason: 'frame $frames');
        if (frames == 0) expect(tester.getRect(shown), rectMoreOrLessEquals(tile, epsilon: 0.01));
        frames++;
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(frames, greaterThan(5));
      await tester.pumpAndSettle();

      // The landed card keeps it under its own picture, which fades in over it once decoded.
      expect(tester.widget<RawImage>(shown).image!.isCloneOf(decoded), isTrue);
      expect(tester.getRect(shown), const Rect.fromLTWH(0, 0, 800, 300));
      final Stack layers = tester.widget<Stack>(
        find.ancestor(of: find.byKey(_artKey), matching: find.byType(Stack)).first,
      );
      expect((layers.children.first as Image).image, same(picture));
      expect(layers.children.last.key, _artKey);
      expect(_tileDecodes, 1, reason: 'The flight and the card reuse the decode the tile already has.');
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('a card Hero with no tile to fly from keeps the plain fade', (tester) async {
    final router = await _pumpRouter(tester);
    unawaited(router.push<void>(const PageRouteInfo<void>('Lone')));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getRect(find.byKey(_bodyKey)), const Rect.fromLTWH(0, 300, 800, 100));
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.byKey(_bodyKey), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, lessThan(1));
      // The grid behind stays still while the page fades in over it.
      expect(tester.getRect(find.byKey(_otherTileKey)), const Rect.fromLTWH(600, 400, 100, 140));
    }
    await tester.pumpAndSettle();
    expect(router.current.name, 'Lone');
  }, variant: TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('a second tap while the page grows cannot open another page', (tester) async {
    final router = await _pumpRouter(tester);
    await tester.tap(find.byKey(_tileKey));
    for (var i = 0; i < 4 && find.byKey(_artKey).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 40));
    expect(router.detailRoute!.animation!.isAnimating, isTrue);
    // The other tile is outside the growing window.
    await tester.tapAt(const Offset(650, 470));
    await tester.pumpAndSettle();
    expect(router.stack.map((page) => page.name), ['Grid', 'Zoom']);
  });

  testWidgets('a detail below another detail retains its unkeyed state across delegated wrapper changes', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('count 0').first);
    await tester.pumpAndSettle();
    expect(find.text('count 1'), findsOneWidget);

    unawaited(router.push<void>(const PageRouteInfo<void>('Zoom')));
    await tester.pumpAndSettle();
    expect(find.text('count 1', skipOffstage: false), findsOneWidget);

    unawaited(router.maybePop<void>());
    await tester.pumpAndSettle();
    expect(router.current.name, 'Detail');
    expect(find.text('count 1'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final routeName in ['Lone', 'Zoom']) {
      testWidgets('$platform taps outside $routeName during pop do not open another route', (tester) async {
        final router = await _pumpRouter(tester);
        unawaited(router.push<void>(PageRouteInfo<void>(routeName)));
        await tester.pumpAndSettle();

        unawaited(router.maybePop<void>());
        await tester.pump();
        expect(router.detailRoute!.animation!.status, AnimationStatus.reverse);
        if (routeName == 'Zoom') await tester.pump(const Duration(milliseconds: 40));
        await tester.tapAt(const Offset(650, 470));
        await tester.pumpAndSettle();

        expect(router.current.name, 'Grid');
        expect(router.stack.map((page) => page.name), ['Grid']);
      }, variant: TargetPlatformVariant({platform}));
    }
  }

  testWidgets('iOS back during the opening shrinks the page back into the tile instead of sliding', (tester) async {
    final router = await _pumpRouter(tester);
    final tile = tester.getRect(find.byKey(_tileKey));
    unawaited(router.push<void>(const PageRouteInfo<void>('Zoom')));
    for (var i = 0; i < 4 && find.byKey(_artKey).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 60));
    unawaited(router.maybePop<void>());
    await tester.pump();
    var frames = 0;
    while (router.detailRoute!.animation!.isAnimating) {
      final art = tester.getRect(find.byKey(_artKey));
      final body = tester.getRect(find.byKey(_bodyKey));
      expect(router.detailRoute!.animation!.status, AnimationStatus.reverse);
      expect(body.left, closeTo(art.left, 0.01), reason: 'frame $frames');
      expect(body.width, closeTo(art.width, 0.01), reason: 'frame $frames');
      expect(body.top, closeTo(art.top + art.width * 300 / 800, 0.01), reason: 'frame $frames');
      frames++;
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(frames, greaterThan(2));
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
    expect(tester.getRect(find.byKey(_tileKey)), tile);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS Zoom edge back slides the foreground and keeps the page behind unscaled', (tester) async {
    final router = await _pumpRouter(tester);
    final Rect tile = tester.getRect(find.byKey(_tileKey));
    unawaited(router.push<void>(const PageRouteInfo<void>('Zoom')));
    await tester.pumpAndSettle();

    final Finder previousTile = find.byKey(_otherTileKey, skipOffstage: false);
    final double nativeParallaxX = tester.getRect(previousTile).left;
    // The hidden page behind rests in place. It takes the native parallax once a back starts.
    expect(nativeParallaxX, 600);
    expect(tester.getRect(previousTile).width, 100);

    final cancel = await tester.startGesture(const Offset(1, 250));
    await cancel.moveBy(const Offset(100, 0));
    await tester.pump();
    await cancel.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    expect(tester.getRect(find.byKey(_bodyKey)).left, closeTo(180, 1));
    expect(tester.getRect(previousTile).left, closeTo(600 - 800 / 3 * router.detailRoute!.animation!.value, 1));
    expect(tester.getRect(previousTile).width, 100);

    await tester.pump(const Duration(milliseconds: 500));
    await cancel.up();
    await tester.pumpAndSettle();
    expect(router.current.name, 'Zoom');
    expect(tester.getRect(find.byKey(_bodyKey)).left, 0);
    expect(tester.getRect(previousTile).left, nativeParallaxX);
    expect(tester.getRect(previousTile).width, 100);

    final complete = await tester.startGesture(const Offset(1, 250));
    await complete.moveBy(const Offset(500, 0));
    await tester.pump();
    await complete.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(tester.getRect(find.byKey(_bodyKey)).left, greaterThan(400));
    expect(tester.getRect(previousTile).width, 100);
    await complete.up();
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
    expect(tester.getRect(find.byKey(_tileKey)), tile);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS PopScope blocks Zoom while opening without leaving a stale behind-page transform', (tester) async {
    final router = await _pumpRouter(tester, allowPop: false);
    unawaited(router.push<void>(const PageRouteInfo<void>('Zoom')));
    for (var i = 0; i < 4 && router.detailRoute == null; i++) {
      await tester.pump();
    }
    expect(router.detailRoute, isNotNull);
    expect(router.detailRoute!.animation!.isAnimating, isTrue);
    expect(await router.maybePop<void>(), isTrue);
    await tester.pumpAndSettle();

    expect(router.current.name, 'Zoom');
    expect(router.detailRoute!.animation!.isCompleted, isTrue);
    final Rect otherTile = tester.getRect(find.byKey(_otherTileKey, skipOffstage: false));
    expect(otherTile.left, 600);
    expect(otherTile.width, 100);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reduced motion opens a card Hero page in place, without a zoom', (tester) async {
    final router = await _pumpRouter(tester, reduceMotion: true);
    unawaited(router.push<void>(const PageRouteInfo<void>('Zoom')));
    await tester.pump();
    await tester.pump();
    expect(router.detailRoute!.animation!.isCompleted, isTrue);
    expect(tester.getRect(find.byKey(_artKey)), const Rect.fromLTWH(0, 0, 800, 300));
    expect(tester.getRect(find.byKey(_bodyKey)), const Rect.fromLTWH(0, 300, 800, 100));
  });

  testWidgets('reduced motion leaves the page behind in place', (tester) async {
    final router = await _pumpRouter(tester, reduceMotion: true);
    unawaited(router.push<void>(const PageRouteInfo<void>('Zoom')));
    await tester.pump();
    await tester.pump();
    unawaited(router.maybePop<void>());
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_otherTileKey)), const Rect.fromLTWH(600, 400, 100, 140));
    expect(router.current.name, 'Grid');
  });

  testWidgets('iOS edge back follows the finger, cancels without losing state, and completes', (tester) async {
    final router = await _pumpRouter(tester);
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pumpAndSettle();
    final Finder previousTile = find.byKey(_otherTileKey, skipOffstage: false);
    final double nativeParallaxX = tester.getRect(previousTile).left;
    // The hidden page behind rests in place. It takes the native parallax once a back starts.
    expect(nativeParallaxX, 600);
    await tester.tap(find.text('count 0'));
    await tester.pump();

    final cancel = await tester.startGesture(const Offset(1, 250));
    await cancel.moveBy(const Offset(100, 0));
    await tester.pump();
    await cancel.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dx, closeTo(180, 1));
    expect(tester.getRect(previousTile).left, closeTo(600 - 800 / 3 * router.detailRoute!.animation!.value, 1));
    await tester.pump(const Duration(milliseconds: 500));
    await cancel.up();
    await tester.pumpAndSettle();
    expect(router.current.name, 'Detail');
    expect(find.text('count 1'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));

    final complete = await tester.startGesture(const Offset(1, 250));
    await complete.moveBy(const Offset(500, 0));
    await tester.pump();
    await complete.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dx, greaterThan(400));
    await complete.up();
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
    expect(find.byKey(_tileKey), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS reduced motion keeps edge back interactive without translating the page', (tester) async {
    final router = await _pumpRouter(tester, reduceMotion: true);
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(1, 250));
    await gesture.moveBy(const Offset(500, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS respects a PopScope that blocks back navigation', (tester) async {
    final router = await _pumpRouter(tester, allowPop: false);
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(1, 250), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isFalse);
    expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
    expect(await router.maybePop<void>(), isTrue);
    await tester.pumpAndSettle();
    expect(router.current.name, 'Detail');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
