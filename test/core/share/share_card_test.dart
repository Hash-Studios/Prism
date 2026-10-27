import 'dart:ui' as ui;

import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Color> _palette = <Color>[
  Color(0xFF1A1A2E),
  Color(0xFF16213E),
  Color(0xFF0F3460),
  Color(0xFFE94560),
  Color(0xFF533483),
  Color(0xFF00ADB5),
];

const ShareCardContent _withCreator = ShareCardContent(
  imageUrl: '',
  link: 'https://prismwalls.com/s/abc',
  brandName: 'Prism',
  contextLine: 'Wall of the Day',
  creator: '@maya',
  creatorLine: 'by @maya',
  palette: _palette,
);

const ShareCardContent _bare = ShareCardContent(imageUrl: '', link: 'https://prismwalls.com/s/abc', brandName: 'Prism');

final Finder _dots = find.byWidgetPredicate(
  (Widget widget) =>
      widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('share-card-dot-'),
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required ShareCardContent content,
    ShareCardFormat format = ShareCardFormat.story,
  }) async {
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
            child: ShareCard(wallpaper: wall, logo: logo, content: content, format: format),
          ),
        ),
      ),
    );
  }

  const Map<ShareCardFormat, Size> expectedSizes = <ShareCardFormat, Size>{
    ShareCardFormat.story: Size(1080, 1920),
    ShareCardFormat.post: Size(1080, 1350),
    ShareCardFormat.clean: Size(1080, 1920),
  };

  for (final ShareCardFormat format in ShareCardFormat.values) {
    testWidgets('${format.name} format sizes the card to its fixed pixel size', (tester) async {
      await pumpCard(tester, content: _withCreator, format: format);

      expect(format.size, expectedSizes[format]);
      expect(tester.getSize(find.byType(ShareCard)), format.size);
    });
  }

  testWidgets('story with creator and palette shows brand, context, byline, link and 4 dots', (tester) async {
    await pumpCard(tester, content: _withCreator);

    expect(find.text('Prism'), findsOneWidget);
    expect(find.text('Wall of the Day'), findsOneWidget);
    expect(find.text('by @maya'), findsOneWidget);
    expect(find.text('prismwalls.com/s/abc'), findsOneWidget);
    expect(_dots, findsNWidgets(4));
  });

  testWidgets('story with no creator and no palette has no byline and no dots', (tester) async {
    await pumpCard(tester, content: _bare);

    expect(find.text('Prism'), findsOneWidget);
    expect(find.text('prismwalls.com/s/abc'), findsOneWidget);
    expect(find.textContaining('by '), findsNothing);
    expect(find.byType(Text), findsNWidgets(2));
    expect(_dots, findsNothing);
  });

  testWidgets('post with creator and palette shows the same content with 4 dots', (tester) async {
    await pumpCard(tester, content: _withCreator, format: ShareCardFormat.post);

    expect(tester.getSize(find.byType(ShareCard)), const Size(1080, 1350));
    expect(find.text('Prism'), findsOneWidget);
    expect(find.text('Wall of the Day'), findsOneWidget);
    expect(find.text('by @maya'), findsOneWidget);
    expect(find.text('prismwalls.com/s/abc'), findsOneWidget);
    expect(_dots, findsNWidgets(4));
  });

  testWidgets('clean with creator shows only the creator mark and the logo', (tester) async {
    await pumpCard(tester, content: _withCreator, format: ShareCardFormat.clean);

    expect(find.text('@maya'), findsOneWidget);
    expect(find.text('Prism'), findsNothing);
    expect(find.text('prismwalls.com/s/abc'), findsNothing);
    expect(find.text('Wall of the Day'), findsNothing);
    expect(_dots, findsNothing);
  });

  testWidgets('clean with no creator has no text and draws the wallpaper and logo', (tester) async {
    await pumpCard(tester, content: _bare, format: ShareCardFormat.clean);

    expect(find.byType(Text), findsNothing);
    expect(find.byType(RawImage), findsNWidgets(2));
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
            ShareCard(
              wallpaper: wall,
              logo: logo,
              content: ShareCardContent(imageUrl: '', link: link, brandName: 'Prism', contextLine: contextLine),
            ),
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
