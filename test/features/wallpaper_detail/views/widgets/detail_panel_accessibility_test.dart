import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_local_store.dart';

final WallpaperDetailLoaded _loaded = WallpaperDetailLoaded(
  entity: FeedItemEntity.prism(
    id: 'wall-1',
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: 'wall-1',
        source: WallpaperSource.prism,
        fullUrl: '',
        thumbnailUrl: '',
        resolution: '1440x3200',
        sizeBytes: 2500000,
        authorName: 'A long author name',
        category: 'abstract',
        createdAt: DateTime(2026),
      ),
      firestoreDocumentId: 'wall-1',
    ),
  ),
  colors: const <Color>[],
);

void main() {
  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });
  tearDown(() => getIt.reset());

  Future<void> pumpPanel(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ValueNotifier<bool> contentVisible = ValueNotifier<bool>(false);
    addTearDown(contentVisible.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(390, 1000), textScaler: TextScaler.linear(textScale)),
          child: Builder(
            builder: (context) => Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: DetailPanel.collapsedHeight(context),
                  child: DetailPanel(
                    state: _loaded,
                    sourceContext: 'test',
                    contentVisible: contentVisible,
                    onToggle: () {},
                    onScrollStart: () {},
                    onScrollEnd: () {},
                    onResetColor: () {},
                    onSelectColor: (_) {},
                    onCopyColor: (_) {},
                    onDownloaded: () {},
                    onSet: () {},
                    onFavourited: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('collapsed title and author stay visible at 3x text', (tester) async {
    await pumpPanel(tester, textScale: 3);

    final Rect panel = tester.getRect(find.byType(DetailPanel));
    for (final Finder finder in <Finder>[find.text('WALL-1'), find.text('by A long author name')]) {
      expect(finder, findsOneWidget);
      final Text text = tester.widget<Text>(finder);
      final Rect rect = tester.getRect(finder);
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text.data, style: text.style),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(3),
        maxLines: 1,
      )..layout(maxWidth: rect.width);

      expect(rect.left, greaterThanOrEqualTo(panel.left));
      expect(rect.right, lessThanOrEqualTo(panel.right));
      expect(rect.top, greaterThanOrEqualTo(panel.top));
      expect(rect.bottom, lessThanOrEqualTo(panel.bottom));
      expect(rect.height, greaterThanOrEqualTo(painter.height));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed detail handle has a 44 point target', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await pumpPanel(tester);
      final Rect handle = tester.getRect(find.bySemanticsLabel('Expand wallpaper details'));

      expect(handle.height, greaterThanOrEqualTo(44));
    } finally {
      semantics.dispose();
    }
  });
}
