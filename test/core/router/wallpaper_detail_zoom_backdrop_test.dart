import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Router extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Grid',
        builder: (_) => Scaffold(
          key: const ValueKey<String>('grid'),
          body: Stack(
            children: <Widget>[
              const Positioned(
                left: 24,
                top: 48,
                width: 120,
                height: 180,
                child: Hero(
                  tag: 'a',
                  createRectTween: wallpaperHeroRectTween,
                  child: ColoredBox(color: Colors.green),
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
        builder: (_) => const Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              height: 360,
              child: WallpaperDetailHero(
                tag: 'a',
                radius: 16,
                image: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

void main() {
  testWidgets(
    'the shrinking page behind the zoom sits on the page colour, never the black root',
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS}),
    (tester) async {
      final router = _Router();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      });
      final ThemeData theme = ThemeData(scaffoldBackgroundColor: const Color(0xFFF4F1EA));
      await tester.pumpWidget(MaterialApp.router(theme: theme, routerConfig: router.config()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final Size screen = tester.getSize(find.byType(Navigator).first);
      final Rect grid = tester.getRect(find.byKey(const ValueKey<String>('grid')));
      expect(grid.width, lessThan(screen.width), reason: 'the page behind shrinks around its tile mid-zoom');

      final Finder backdrop = find.ancestor(
        of: find.byKey(const ValueKey<String>('grid')),
        matching: find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == theme.scaffoldBackgroundColor,
        ),
      );
      expect(backdrop, findsOneWidget, reason: 'the uncovered screen edges must paint the page colour');
      expect(tester.getRect(backdrop), Offset.zero & screen);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
