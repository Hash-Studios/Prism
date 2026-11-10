import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/live_tag.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: home!,
  ),
  home: Scaffold(body: Center(child: child)),
);

FeedItemEntity _item(WallLive? live) => FeedItemEntity.prism(
  id: 'wall',
  wallpaper: PrismWallpaper(
    core: const WallpaperCore(id: 'wall', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
    live: live,
  ),
);

void main() {
  testWidgets('LiveTag shows Live with the Live wallpaper screen reader label', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const LiveTag()));

    expect(find.text('Live'), findsOneWidget);
    expect(find.bySemanticsLabel('Live wallpaper'), findsOneWidget);
  });

  test('liveTagFor gives a tag only for a live wall', () {
    expect(liveTagFor(WallKind.still), isNull);
    expect(liveTagFor(WallKind.live), isNotNull);
  });

  test('kindOf reads live from a Prism wall', () {
    const WallLive live = WallLive(videoUrl: 'https://img.example.com/previews/x.mp4');

    expect(kindOf(_item(live)), WallKind.live);
    expect(kindOf(_item(null)), WallKind.still);
  });

  testWidgets('LiveTag does not overflow a narrow tile at large text', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const SizedBox(width: 120, child: LiveTag()), textScaler: const TextScaler.linear(2)));

    expect(tester.takeException(), isNull);
  });
}
