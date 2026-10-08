import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/interest_category_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

void main() {
  late _MockCacheManager cache;

  setUp(() {
    cache = _MockCacheManager();
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => const Stream<FileResponse>.empty());
    PrismImageCache.testOverride = cache;
  });

  tearDown(() => PrismImageCache.testOverride = null);

  testWidgets('the cover loads through the shared thumbnail cache at the size of the tile', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: InterestCategoryTile(
              name: 'Nature',
              imageUrl: 'https://example.com/nature.jpg',
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, 'https://example.com/nature.jpg');
    expect(image.cacheManager, same(cache));
    expect(image.memCacheWidth, 200);
  });

  testWidgets('a tile without a cover shows no image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: InterestCategoryTile(name: 'Nature', isSelected: true, onTap: () {}),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('Nature'), findsOneWidget);
  });
}
