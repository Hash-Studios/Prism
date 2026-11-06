import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _heightAt(WidgetTester tester, Size size) async {
  late double height;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Builder(
        builder: (BuildContext context) {
          height = feedCarouselCardHeight(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return height;
}

void main() {
  test('feedCarouselColumns keeps phones at one card and gives tablets more', () {
    expect(feedCarouselColumns(320), 1);
    expect(feedCarouselColumns(393), 1);
    expect(feedCarouselColumns(440), 1);
    expect(feedCarouselColumns(599), 1);
    expect(feedCarouselColumns(744), 1);
    expect(feedCarouselColumns(834), 1);
    expect(feedCarouselColumns(960), 2);
    expect(feedCarouselColumns(1032), 2);
    expect(feedCarouselColumns(1280), 2);
    expect(feedCarouselColumns(1376), 2);
    expect(feedCarouselColumns(1920), 3);
  });

  testWidgets('feedCarouselCardHeight is a wide banner on a phone', (WidgetTester tester) async {
    expect(
      await _heightAt(tester, const Size(393, 852)),
      (393 - PrismFeedLayout.gridPadding.horizontal) * feedCarouselAspect,
    );
  });

  testWidgets('feedCarouselCardHeight uses half the width on a tablet', (WidgetTester tester) async {
    expect(
      await _heightAt(tester, const Size(1032, 1376)),
      (1032 / 2 - PrismFeedLayout.gridPadding.horizontal) * feedCarouselAspect,
    );
  });

  testWidgets('feedCarouselCardHeight is 0, not negative, before the screen has a width', (WidgetTester tester) async {
    expect(await _heightAt(tester, Size.zero), 0);
  });

  testWidgets('the carousel skeleton mounts on a zero-size first frame', (WidgetTester tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(builder: (BuildContext context) => PrismBone(height: feedCarouselCardHeight(context))),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('iPhone Duo', () {
    Future<double> heightOnDuo(WidgetTester tester, {required Size size, required EdgeInsets padding}) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size
        ..viewPadding = FakeViewPadding(top: padding.top, right: padding.right, bottom: padding.bottom);
      addTearDown(tester.view.reset);
      late double height;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view),
          child: Builder(
            builder: (BuildContext context) {
              height = feedCarouselCardHeight(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return height;
    }

    testWidgets('the unfolded screen in landscape shows two cards beside the rail', (WidgetTester tester) async {
      final double height = await heightOnDuo(
        tester,
        size: const Size(951, 669),
        padding: const EdgeInsets.only(right: 84, bottom: 34),
      );
      expect(height, ((951 - 84) / 2 - PrismFeedLayout.gridPadding.horizontal) * feedCarouselAspect);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the unfolded screen in portrait keeps one card', (WidgetTester tester) async {
      final double height = await heightOnDuo(
        tester,
        size: const Size(669, 951),
        padding: const EdgeInsets.only(top: 82, bottom: 34),
      );
      expect(height, (669 - PrismFeedLayout.gridPadding.horizontal) * feedCarouselAspect);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('an Android screen of the same size keeps one card', (WidgetTester tester) async {
      final double height = await heightOnDuo(
        tester,
        size: const Size(951, 669),
        padding: const EdgeInsets.only(right: 84, bottom: 34),
      );
      expect(height, (951 - PrismFeedLayout.gridPadding.horizontal) * feedCarouselAspect);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
