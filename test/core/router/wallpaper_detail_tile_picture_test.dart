import 'dart:async';

import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A provider that never loads, so the test can find the tile's [Image] by identity.
class _TilePicture extends ImageProvider<_TilePicture> {
  @override
  Future<_TilePicture> obtainKey(ImageConfiguration configuration) => SynchronousFuture<_TilePicture>(this);

  @override
  ImageStreamCompleter loadImage(_TilePicture key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

Widget _detailPage(Object tag) => Scaffold(
  body: Center(
    child: SizedBox(
      width: 280,
      height: 360,
      child: WallpaperDetailHero(
        tag: tag,
        radius: 16,
        image: const ColoredBox(color: Colors.blue),
      ),
    ),
  ),
);

class _Router extends RootStackRouter {
  _Router({required this.picture, required this.cardTag});

  final ImageProvider picture;
  final ValueNotifier<Object> cardTag;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Grid',
        builder: (_) => Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(
                left: 24,
                top: 48,
                width: 120,
                height: 180,
                child: Hero(
                  tag: 'a',
                  createRectTween: wallpaperHeroRectTween,
                  child: Image(image: picture, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: 24,
                bottom: 24,
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => context.router.push<void>(const PageRouteInfo<void>('Detail')),
                    child: const Text('Open'),
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
        builder: (_) =>
            ValueListenableBuilder<Object>(valueListenable: cardTag, builder: (_, Object tag, _) => _detailPage(tag)),
      ),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

Finder _pictureUnderCard(ImageProvider picture) => find.descendant(
  of: find.byType(WallpaperDetailHero),
  matching: find.byWidgetPredicate((widget) => widget is Image && identical(widget.image, picture)),
);

void main() {
  testWidgets('the tile picture shows under the card for its own tag only', (tester) async {
    final picture = _TilePicture();
    final cardTag = ValueNotifier<Object>('a');
    final router = _Router(picture: picture, cardTag: cardTag);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      cardTag.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();
    expect(_pictureUnderCard(picture), findsOneWidget);

    // A swipe to another wall rebuilds the card with a new Hero tag. The first wall's picture must not show.
    cardTag.value = 'b';
    await tester.pump();
    expect(_pictureUnderCard(picture), findsNothing);
  });
}
