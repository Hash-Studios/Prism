import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BuildContext context;

  Future<void> pumpContext(WidgetTester tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
  }

  Future<File> okRender({required String imageUrl, required String link, String? contextLine}) async =>
      File('card.png');
  Future<File> failRender({required String imageUrl, required String link, String? contextLine}) async =>
      throw StateError('no image');

  testWidgets('shares the card file with the link text when rendering works', (tester) async {
    await pumpContext(tester);
    File? sent;
    String? sentText;

    final ShareFormatValue format = await shareWallpaperCard(
      context,
      imageUrl: 'u',
      link: 'https://x.test/a',
      render: okRender,
      sendCard: ({required String text, required File file, required BuildContext context}) async {
        sent = file;
        sentText = text;
      },
      sendText: ({required String text, required BuildContext context}) async => fail('text fallback used'),
    );

    expect(format, ShareFormatValue.card);
    expect(sent?.path, 'card.png');
    expect(sentText, contains('https://x.test/a'));
  });

  testWidgets('falls back to the text link when rendering fails', (tester) async {
    await pumpContext(tester);
    final List<String> texts = <String>[];

    final ShareFormatValue format = await shareWallpaperCard(
      context,
      imageUrl: 'u',
      link: 'https://x.test/a',
      render: failRender,
      sendCard: ({required String text, required File file, required BuildContext context}) async => fail('card sent'),
      sendText: ({required String text, required BuildContext context}) async => texts.add(text),
    );

    expect(format, ShareFormatValue.text);
    expect(texts.single, contains('https://x.test/a'));
  });

  testWidgets('falls back to the text link when sending the card fails', (tester) async {
    await pumpContext(tester);
    final List<String> texts = <String>[];

    final ShareFormatValue format = await shareWallpaperCard(
      context,
      imageUrl: 'u',
      link: 'https://x.test/a',
      render: okRender,
      sendCard: ({required String text, required File file, required BuildContext context}) async =>
          throw StateError('share failed'),
      sendText: ({required String text, required BuildContext context}) async => texts.add(text),
    );

    expect(format, ShareFormatValue.text);
    expect(texts.single, contains('https://x.test/a'));
  });

  testWidgets('paints a real 1080x1920 PNG off-screen', (tester) async {
    await tester.runAsync(() async {
      final ui.Image wall = await createTestImage(width: 54, height: 96);
      final ui.Image logo = await createTestImage(width: 10, height: 10);
      final ByteData? bytes = await paintShareCard(
        ShareCard(wallpaper: wall, logo: logo, link: 'https://prismwalls.com', contextLine: 'by A'),
      );
      expect(bytes, isNotNull);
      final ui.Codec codec = await ui.instantiateImageCodec(bytes!.buffer.asUint8List());
      final ui.Image decoded = (await codec.getNextFrame()).image;
      expect((decoded.width, decoded.height), (1080, 1920));
    });
  });
}
