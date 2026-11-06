import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/interest_category_tile.dart';
import 'package:Prism/l10n/l10n.dart';
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    // 100 points less the 3 point ring on each side, at 2x.
    expect(image.memCacheWidth, 188);
  });

  testWidgets('the cover decode size does not change when the tile is selected', (tester) async {
    Future<int?> decodeWidth({required bool selected}) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: InterestCategoryTile(
                name: 'Nature',
                imageUrl: 'https://example.com/nature.jpg',
                isSelected: selected,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).memCacheWidth;
    }

    final int? unselected = await decodeWidth(selected: false);
    final int? selected = await decodeWidth(selected: true);
    expect(selected, unselected);
  });

  testWidgets('a stock cover shows the bundled copy and never waits on Pexels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 100,
          height: 100,
          child: InterestCategoryTile(
            name: 'Birds',
            imageUrl:
                'https://images.pexels.com/photos/326900/pexels-photo-326900.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940',
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    final ResizeImage image = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(image.imageProvider, const AssetImage('assets/images/covers/326900.webp'));
  });

  testWidgets('a tile without a cover shows no image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('a selected tile has a 3 point white ring and a white tick disc, whatever the accent', (tester) async {
    const ColorScheme scheme = ColorScheme.light(primary: Color(0xFFE91E63));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 100,
          height: 100,
          child: InterestCategoryTile(name: 'Nature', isSelected: true, onTap: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Iterable<BoxDecoration> decorations = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>();
    final Border ring = decorations.map((d) => d.border).whereType<Border>().single;
    expect(ring.top.color, Colors.white);
    expect(ring.top.width, 3);
    final Iterable<Color?> fills = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color);
    expect(fills, contains(Colors.white));
    expect(fills, isNot(contains(scheme.primary)));
    expect(tester.widget<Icon>(find.byIcon(Icons.check_rounded)).color, Colors.black);
  });

  testWidgets('the label scrim darkens the lower part of the tile to 0.75', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 100,
          height: 100,
          child: InterestCategoryTile(name: 'Nature', isSelected: false, onTap: () {}),
        ),
      ),
    );

    final LinearGradient scrim = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((b) => b.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        .single;
    expect(scrim.colors.last.a, closeTo(0.75, 0.01));
    expect(scrim.begin, const Alignment(0, -0.1));
  });
}
