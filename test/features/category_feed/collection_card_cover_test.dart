import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/category_feed/views/widgets/collection_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

void main() {
  setUp(() {
    final cache = _MockCacheManager();
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => Stream<FileResponse>.error(const HttpExceptionWithStatus(504, 'Gateway timeout')));
    PrismImageCache.testOverride = cache;
  });

  tearDown(() {
    PrismImageCache.testOverride = null;
    PaintingBinding.instance.imageCache.clear();
  });

  Future<void> pumpCard(WidgetTester tester, String thumbUrl) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: SizedBox(
          width: 180,
          height: 250,
          child: CollectionCard(
            data: CollectionCardData(
              kind: CollectionCardKind.category,
              name: 'Birds',
              thumbUrl: thumbUrl,
              isPremium: false,
            ),
            onTap: () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('a cover that times out leaves a calm card and reports no error', (tester) async {
    await pumpCard(tester, 'https://example.com/birds.jpg');
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Birds'), findsOneWidget);
  });

  testWidgets('a stock category cover uses the bundled copy', (tester) async {
    await pumpCard(
      tester,
      'https://images.pexels.com/photos/326900/pexels-photo-326900.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940',
    );

    final ResizeImage image = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(image.imageProvider, const AssetImage('assets/images/covers/326900.webp'));
  });
}
