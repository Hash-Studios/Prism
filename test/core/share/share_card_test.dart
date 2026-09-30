import 'dart:ui' as ui;

import 'package:Prism/core/share/share_card.dart';
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
}
