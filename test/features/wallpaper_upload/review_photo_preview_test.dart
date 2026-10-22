import 'package:Prism/features/wallpaper_upload/views/widgets/review_photo_preview.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_view/photo_view.dart';

import '../../support/wait_for_real_io.dart';

class _Cache extends Mock implements BaseCacheManager {}

void main() {
  setUpAll(() => CachedNetworkImageProvider.defaultCacheManager = _Cache());
  late BaseCacheManager original;
  setUp(() {
    original = CachedNetworkImageProvider.defaultCacheManager;
    final cache = _Cache();
    when(
      () => cache.getFileStream(any(), withProgress: true),
    ).thenAnswer((_) => Stream<FileResponse>.error(StateError('offline')));
    CachedNetworkImageProvider.defaultCacheManager = cache;
  });
  tearDown(() {
    CachedNetworkImageProvider.defaultCacheManager = original;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  testWidgets('a failed full image keeps an error message and a working close action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showReviewPhotoPreview(context, url: '', thumbUrl: ''),
            child: const Text('Review upload'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review upload'));
    await tester.pumpAndSettle();
    await waitForRealIo(
      tester,
      () => find.byIcon(Icons.broken_image_rounded).evaluate().isNotEmpty,
      reason: 'failed full image to show its error',
    );
    expect(find.byType(PhotoView), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
    expect(find.text("Couldn't load the full image."), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Review upload'), findsOneWidget);
    expect(find.byType(ReviewPhotoPreview), findsNothing);
  });
}
