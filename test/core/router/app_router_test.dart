import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackedAnimation extends Animation<double> {
  int statusListeners = 0;

  @override
  double get value => 0.5;

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) => statusListeners++;

  @override
  void removeStatusListener(AnimationStatusListener listener) => statusListeners--;
}

void main() {
  test('old streak and coin history links resolve to rewards', () {
    final router = AppRouter();
    for (final path in ['/streak', '/coin-transactions']) {
      expect(router.matcher.match(path)?.last.name, RewardsRoute.name);
    }
    final dashboard = router.matcher.match('/dashboard/streak');
    expect(dashboard?.last.children?.last.name, RewardsTabRoute.name);
    expect(RewardsRoute().args?.showBack, isTrue);
  });

  testWidgets('rebuilding route transitions does not retain animation status listeners', (tester) async {
    final transition = (AppRouter().defaultRouteType as CustomRouteType).transitionsBuilder!;
    final animation = _TrackedAnimation();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            for (var i = 0; i < 100; i++) {
              transition(context, animation, animation, const SizedBox());
            }
            return const SizedBox();
          },
        ),
      ),
    );
    expect(animation.statusListeners, 0);
  });
  test('a share link the parser rejects opens not-found, not an empty wallpaper screen', () {
    final matches = AppRouter().matcher.match('/share');

    expect(matches?.last.name, NotFoundRoute.name);
  });

  test('the referral invite screen is reachable from outside the profile tab', () {
    final matches = AppRouter().matcher.match('/share-prism');

    expect(matches?.map((m) => m.name), <String>[SharePrismRoute.name]);
  });
}
