import 'package:Prism/features/favourite_walls/views/widgets/favourite_tile_image.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _thumbnail = 'https://example.test/thumbnail.jpg';
const _original = 'https://example.test/original.jpg';

Future<Widget> _buildPreview(WidgetTester tester, FavouriteTileImage image, {bool failPrimary = false}) async {
  late Widget preview;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          preview = (image.build(context) as SizedBox).child!;
          if (failPrimary && preview is CachedNetworkImage) {
            final networkImage = preview as CachedNetworkImage;
            preview = networkImage.errorWidget!(context, networkImage.imageUrl, Exception('Thumbnail failed'));
          }
          return preview is CachedNetworkImage ? const SizedBox() : preview;
        },
      ),
    ),
  );
  return preview;
}

void main() {
  testWidgets('external preview retains original fallback after thumbnail failure', (tester) async {
    final preview = await _buildPreview(
      tester,
      FavouriteTileImage(
        thumbnailUrl: _thumbnail,
        fullUrl: _original,
        allowFullUrlFallback: true,
        onUnavailable: () {},
      ),
      failPrimary: true,
    );

    expect(preview, isA<CachedNetworkImage>());
    expect((preview as CachedNetworkImage).imageUrl, _original);
  });

  testWidgets('external preview retains original fallback with a missing thumbnail', (tester) async {
    final preview = await _buildPreview(
      tester,
      FavouriteTileImage(thumbnailUrl: '', fullUrl: _original, allowFullUrlFallback: true, onUnavailable: () {}),
    );

    expect(preview, isA<CachedNetworkImage>());
    expect((preview as CachedNetworkImage).imageUrl, _original);
  });

  testWidgets('Prism preview uses the thumbnail and never falls back to its original on failure', (tester) async {
    var unavailable = 0;
    final image = FavouriteTileImage(thumbnailUrl: _thumbnail, fullUrl: _original, onUnavailable: () => unavailable++);

    final primary = await _buildPreview(tester, image);
    expect(primary, isA<CachedNetworkImage>());
    expect((primary as CachedNetworkImage).imageUrl, _thumbnail);

    final failed = await _buildPreview(tester, image, failPrimary: true);
    expect(failed, isNot(isA<CachedNetworkImage>()));
    expect(find.text('Unavailable'), findsOneWidget);
    expect(unavailable, greaterThan(0));
  });

  for (final thumbnail in <String>['', '   ']) {
    testWidgets('Prism preview with missing thumbnail "$thumbnail" never loads the original', (tester) async {
      var unavailable = 0;
      final preview = await _buildPreview(
        tester,
        FavouriteTileImage(thumbnailUrl: thumbnail, fullUrl: _original, onUnavailable: () => unavailable++),
      );

      expect(preview, isNot(isA<CachedNetworkImage>()));
      expect(find.text('Unavailable'), findsOneWidget);
      expect(unavailable, greaterThan(0));
    });
  }
}
