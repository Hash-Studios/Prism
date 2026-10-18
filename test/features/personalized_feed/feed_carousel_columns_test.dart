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

  testWidgets('feedCarouselCardHeight is unchanged on a phone', (WidgetTester tester) async {
    expect(await _heightAt(tester, const Size(393, 852)), (393 - 2 * PrismFeedLayout.gridSpacing) * 0.6);
  });

  testWidgets('feedCarouselCardHeight uses half the width on a tablet', (WidgetTester tester) async {
    expect(await _heightAt(tester, const Size(1032, 1376)), (1032 / 2 - 2 * PrismFeedLayout.gridSpacing) * 0.6);
  });
}
