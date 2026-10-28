import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/widgets/spatial_tag.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void onPlatform(String name, TargetPlatform platform, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  group('spatialTagFor', () {
    onPlatform('gives a tag for great and ok walls on iOS, and none for the rest', TargetPlatform.iOS, (_) async {
      expect(spatialTagFor(WallSpatialTier.great), isNotNull);
      expect(spatialTagFor(WallSpatialTier.ok), isNotNull);
      expect(spatialTagFor(WallSpatialTier.none), isNull);
      expect(spatialTagFor(null), isNull);
    });

    onPlatform('gives no tag on Android, where Spatial Scenes do not exist', TargetPlatform.android, (_) async {
      expect(spatialTagFor(WallSpatialTier.great), isNull);
      expect(spatialTagFor(WallSpatialTier.ok), isNull);
    });

    for (final WallSpatialTier tier in <WallSpatialTier>[WallSpatialTier.great, WallSpatialTier.ok]) {
      onPlatform('a ${tier.name} wall shows the Spatial tag with a label at the bottom end', TargetPlatform.iOS, (
        tester,
      ) async {
        const ValueKey<String> tileKey = ValueKey<String>('tile');
        final AppLocalizationsEn l10n = AppLocalizationsEn();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: tileKey,
                  width: 116,
                  height: 232,
                  child: Stack(children: <Widget>[spatialTagFor(tier)!]),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SpatialTag), findsOneWidget);
        expect(find.text(l10n.coreSpatialBadge), findsOneWidget);
        final Rect tile = tester.getRect(find.byKey(tileKey));
        final Rect tag = tester.getRect(find.byType(SpatialTag));
        expect(tile.right - tag.right, 6);
        expect(tile.bottom - tag.bottom, 6);
      });
    }
  });

  group('stackTags', () {
    testWidgets('gives null for no layers', (tester) async {
      expect(stackTags(<Widget?>[]), isNull);
      expect(stackTags(<Widget?>[null, null]), isNull);
    });

    testWidgets('gives the one layer as it is', (tester) async {
      const Text layer = Text('layer');
      expect(stackTags(<Widget?>[null, layer]), same(layer));
    });

    testWidgets('gives a stack for two layers', (tester) async {
      expect(stackTags(<Widget?>[const Text('a'), const Text('b')]), isA<Stack>());
    });
  });
}
