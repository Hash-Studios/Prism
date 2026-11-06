import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
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
      onPlatform(
        'a ${tier.name} wall shows a 24 point icon badge at the top end, even with large text',
        TargetPlatform.iOS,
        (tester) async {
          const ValueKey<String> tileKey = ValueKey<String>('tile');
          final AppLocalizationsEn l10n = AppLocalizationsEn();
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      key: tileKey,
                      width: 180,
                      height: 232,
                      child: Stack(children: <Widget>[spatialTagFor(tier)!]),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(SpatialTag), findsOneWidget);
          expect(find.text(l10n.coreSpatialBadge), findsNothing);
          expect(find.byIcon(Icons.view_in_ar_rounded), findsOneWidget);
          expect(find.bySemanticsLabel(l10n.coreSpatialBadgeSemantic), findsOneWidget);
          final Rect tile = tester.getRect(find.byKey(tileKey));
          final Rect tag = tester.getRect(find.byType(SpatialTag));
          expect(tag.size, const Size(24, 24));
          expect(tile.right - tag.right, 8);
          expect(tag.top - tile.top, 8);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  onPlatform('Depth and Spatial badges share one row at the top end and never overlap', TargetPlatform.iOS, (
    tester,
  ) async {
    const ValueKey<String> tileKey = ValueKey<String>('tile');
    final Widget? tags = stackTags(<Widget?>[depthTagFor(WallDepthTier.auto), spatialTagFor(WallSpatialTier.great)]);
    expect(tags, isA<TileBadges>());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: tileKey,
              width: 180,
              height: 232,
              child: Stack(children: <Widget>[tags!]),
            ),
          ),
        ),
      ),
    );

    final Rect tile = tester.getRect(find.byKey(tileKey));
    final Rect depth = tester.getRect(find.byType(DepthTag));
    final Rect spatial = tester.getRect(find.byType(SpatialTag));
    expect(depth.overlaps(spatial), isFalse);
    expect(depth.top, spatial.top);
    expect(tile.right - spatial.right, 8);
    expect(spatial.left - depth.right, 4);
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

    testWidgets('keeps other layers beside the merged badges', (tester) async {
      const Text other = Text('other');
      final Widget? stacked = stackTags(<Widget?>[
        other,
        const TileBadges(badges: <Widget>[SizedBox()]),
        const TileBadges(badges: <Widget>[SizedBox()]),
      ]);
      expect(stacked, isA<Stack>());
      final List<Widget> children = (stacked! as Stack).children;
      expect(children, hasLength(2));
      expect(children.first, same(other));
      expect((children.last as TileBadges).badges, hasLength(2));
    });
  });
}
