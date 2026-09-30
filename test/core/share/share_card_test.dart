import 'dart:ui' as ui;

import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, {String? contextLine}) async {
    late ui.Image wall;
    late ui.Image logo;
    await tester.runAsync(() async {
      wall = await createTestImage(width: 40, height: 80);
      logo = await createTestImage(width: 10, height: 10);
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: FittedBox(
            child: ShareCard(
              wallpaper: wall,
              logo: logo,
              link: 'https://prismwalls.com/s/abc',
              contextLine: contextLine,
            ),
          ),
        ),
      ),
    );
  }

  for (final String line in <String>['Wall of the Day', 'Made with Prism AI', 'by Akshay']) {
    testWidgets('lays out logo, wordmark, "$line" and link at 1080x1920', (tester) async {
      await pumpCard(tester, contextLine: line);

      expect(tester.getSize(find.byType(ShareCard)), ShareCardStyle.size);
      expect(find.byType(RawImage), findsNWidgets(2));
      expect(find.text('Prism'), findsOneWidget);
      expect(find.text(line), findsOneWidget);
      expect(find.text('prismwalls.com/s/abc'), findsOneWidget);
    });
  }

  testWidgets('omits the context line when none is given', (tester) async {
    await pumpCard(tester);

    expect(find.text('Prism'), findsOneWidget);
    expect(find.text('prismwalls.com/s/abc'), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(2));
  });

  testWidgets('paints mixed RTL and very long unbroken text inside the fixed card bounds', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.2;
    try {
      await tester.runAsync(() async {
        final ui.Image wall = await createTestImage(width: 40, height: 80);
        final ByteData logoData = await rootBundle.load(ShareCardStyle.logoAsset);
        final ui.Codec logoCodec = await ui.instantiateImageCodec(logoData.buffer.asUint8List());
        final ui.Image logo = (await logoCodec.getNextFrame()).image;
        final String longCreator = 'مصمم壁紙_' * 300;
        final String longLink = 'https://prismwalls.com/${'wallpaper_' * 300}';

        Future<Uint8List> render({required String link, String? contextLine}) async {
          final ByteData? bytes = await paintShareCard(
            ShareCard(wallpaper: wall, logo: logo, link: link, contextLine: contextLine),
          );
          expect(bytes, isNotNull);
          return bytes!.buffer.asUint8List();
        }

        final Uint8List baseline = await render(link: 'https://prismwalls.com/s/abc');
        final Uint8List withLongText = await render(link: longLink, contextLine: 'بواسطة $longCreator | Prism');
        final ui.Codec codec = await ui.instantiateImageCodec(withLongText);
        final ui.Image output = (await codec.getNextFrame()).image;

        expect((output.width, output.height), (1080, 1920));

        final ByteData pixels = (await output.toByteData())!;
        final ui.Codec baselineCodec = await ui.instantiateImageCodec(baseline);
        final ui.Image baselineImage = (await baselineCodec.getNextFrame()).image;
        final ByteData baselinePixels = (await baselineImage.toByteData())!;
        final Uint8List rgba = pixels.buffer.asUint8List();
        final Uint8List original = baselinePixels.buffer.asUint8List();
        final int minX = ShareCardStyle.padding.toInt();
        final int maxX = 1080 - ShareCardStyle.padding.toInt();
        final int minY = 1920 - ShareCardStyle.scrimHeight.toInt();
        final int maxY = 1920 - ShareCardStyle.padding.toInt();
        int changedPixels = 0;
        int changedMinX = 1080;
        int changedMinY = 1920;
        int changedMaxX = 0;
        int changedMaxY = 0;
        for (int y = 0; y < 1920; y++) {
          for (int x = 0; x < 1080; x++) {
            final int pixel = (y * 1080 + x) * 4;
            if (rgba[pixel] == original[pixel] &&
                rgba[pixel + 1] == original[pixel + 1] &&
                rgba[pixel + 2] == original[pixel + 2] &&
                rgba[pixel + 3] == original[pixel + 3]) {
              continue;
            }
            changedPixels++;
            changedMinX = x < changedMinX ? x : changedMinX;
            changedMaxX = x > changedMaxX ? x : changedMaxX;
            changedMinY = y < changedMinY ? y : changedMinY;
            changedMaxY = y > changedMaxY ? y : changedMaxY;
          }
        }
        expect(changedPixels, greaterThan(0));
        expect(changedMinX, greaterThanOrEqualTo(minX - 1));
        expect(changedMaxX, lessThanOrEqualTo(maxX + 1));
        expect(changedMinY, greaterThanOrEqualTo(minY - 1));
        expect(changedMaxY, lessThanOrEqualTo(maxY + 1));

        output.dispose();
        codec.dispose();
        baselineImage.dispose();
        baselineCodec.dispose();
        wall.dispose();
        logo.dispose();
        logoCodec.dispose();
      });
    } finally {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    }
  });
}
