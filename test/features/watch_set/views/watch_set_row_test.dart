import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/watch_set/views/watch_set_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity wall({bool hasDesktop = true, List<String>? tags}) => FeedItemEntity.prism(
  id: 'w1',
  wallpaper: PrismWallpaper(
    core: const WallpaperCore(
      id: 'w1',
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/w1.jpg',
      thumbnailUrl: 'https://example.com/w1-thumb.jpg',
    ),
    tags: tags,
    desktop: hasDesktop
        ? const WallDesktopVariant(
            version: 'aaaaaaaaaaaaaaaa',
            thumbnailUrl: 'https://example.com/d.jpg',
            width: 2560,
            height: 1600,
          )
        : null,
  ),
);

Widget _host(FeedItemEntity entity) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: WatchSetRow(entity: entity)),
);

void main() {
  testWidgets('shows the desktop subtitle when the wall has a desktop companion', (tester) async {
    await tester.pumpWidget(_host(wall()));

    expect(find.text('Watch set'), findsOneWidget);
    expect(find.text('Phone, watch and desktop, one save'), findsOneWidget);
  });

  testWidgets('shows the phone and watch subtitle when the wall has no desktop companion', (tester) async {
    await tester.pumpWidget(_host(wall(hasDesktop: false)));

    expect(find.text('Watch set'), findsOneWidget);
    expect(find.text('Phone and watch, one save'), findsOneWidget);
    expect(find.text('Phone, watch and desktop, one save'), findsNothing);
  });

  test('watchSetWallOf carries the desktop variant only when the wall has one', () {
    expect(watchSetWallOf(wall()).desktop?.version, 'aaaaaaaaaaaaaaaa');
    expect(watchSetWallOf(wall(hasDesktop: false)).desktop, isNull);
  });

  test('showsWatchSet is true for a single wall and false for a duo wall', () {
    expect(showsWatchSet(wall()), isTrue);
    expect(showsWatchSet(wall(tags: const <String>['duo'])), isFalse);
  });

  testWidgets('the row tap target is at least 44 logical pixels tall', (tester) async {
    await tester.pumpWidget(_host(wall()));

    expect(tester.getSize(find.byKey(const ValueKey<String>('watch-set-row'))).height, greaterThanOrEqualTo(44));
  });

  testWidgets('tapping the row plays one tap haptic', (tester) async {
    const MethodChannel channel = MethodChannel('prism/haptics');
    PrismHaptics.enabled = true;
    final List<String> haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'play') haptics.add(call.arguments! as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(_host(wall()));

    await tester.tap(find.byKey(const ValueKey<String>('watch-set-row')));
    await tester.pump();

    expect(haptics, <String>['tap']);
  });
}
