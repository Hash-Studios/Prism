import 'package:Prism/features/admin_review/views/widgets/full_screen_image_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/wait_for_real_io.dart';

class _Cache extends Mock implements BaseCacheManager {}

void main() {
  setUpAll(() => CachedNetworkImageProvider.defaultCacheManager = _Cache());
  late BaseCacheManager original;
  late int fetches;
  setUp(() {
    original = CachedNetworkImageProvider.defaultCacheManager;
    final cache = _Cache();
    fetches = 0;
    when(() => cache.getFileStream(any(), withProgress: true)).thenAnswer((_) {
      fetches++;
      return Stream<FileResponse>.error(StateError('offline'));
    });
    CachedNetworkImageProvider.defaultCacheManager = cache;
  });
  tearDown(() {
    CachedNetworkImageProvider.defaultCacheManager = original;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  testWidgets('reviewer can zoom at a point, reset, and retry a failed image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => FullScreenImageView.show(context, ''), child: const Text('Open preview')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await waitForRealIo(
      tester,
      () => find.text('Could not load the wallpaper').evaluate().isNotEmpty,
      reason: 'failed preview to show a retry action',
    );
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = viewer.transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), 1);
    final position = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.value.getMaxScaleOnAxis(), 2.5);
    expect(controller.value.getTranslation().x, lessThan(0));
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.value, Matrix4.identity());

    expect(find.text('Could not load the wallpaper'), findsOneWidget);
    final oldKey = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).key;
    final oldFetches = fetches;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).key, isNot(oldKey));
    await waitForRealIo(tester, () => fetches > oldFetches, reason: 'retry to request the image again');
  });

  testWidgets('close returns to the review page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) =>
              TextButton(onPressed: () => FullScreenImageView.show(context, ''), child: const Text('Review')),
        ),
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsOneWidget);
    expect(find.byType(FullScreenImageView), findsNothing);
  });
}
