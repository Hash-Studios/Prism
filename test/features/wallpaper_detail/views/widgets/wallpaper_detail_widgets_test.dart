import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/similar_wallpapers_strip.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_tag_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity _wall(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/$id.jpg',
      thumbnailUrl: 'https://img.test/$id-t.jpg',
    ),
  ),
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('WallpaperActionBar', () {
    testWidgets('shows the labelled primary action and an icon action with a tooltip for each button', (tester) async {
      await tester.pumpWidget(
        _host(
          const WallpaperActionBar(
            primary: WallpaperBarAction(label: 'Set as wallpaper', child: Text('Set')),
            actions: <WallpaperBarAction>[
              WallpaperBarAction(label: 'Download', child: Icon(Icons.download)),
              WallpaperBarAction(label: 'Favourite', child: Icon(Icons.favorite)),
              WallpaperBarAction(label: 'Share', child: Icon(Icons.share)),
              WallpaperBarAction(label: 'Edit', child: Icon(Icons.edit)),
            ],
          ),
        ),
      );

      expect(find.text('Set'), findsOneWidget);
      for (final String label in <String>['Set as wallpaper', 'Download', 'Favourite', 'Share', 'Edit']) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('draws menu buttons bare and the primary action as an accent pill', (tester) async {
      await tester.pumpWidget(
        _host(
          const WallpaperActionBar(
            primary: WallpaperBarAction(
              label: 'Set as wallpaper',
              child: PrimaryActionPill(
                icon: Icons.image,
                label: 'Set',
                semanticLabel: 'Set as wallpaper',
                isLoading: false,
              ),
            ),
            actions: <WallpaperBarAction>[
              WallpaperBarAction(
                label: 'Share',
                child: CircularMenuButton(label: 'Share', isLoading: false, child: Icon(Icons.share)),
              ),
            ],
          ),
        ),
      );

      expect(find.descendant(of: find.byType(CircularMenuButton), matching: find.byType(DecoratedBox)), findsNothing);
      final DecoratedBox pill = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(PrimaryActionPill), matching: find.byType(DecoratedBox)).first,
      );
      final Color accent = Theme.of(tester.element(find.byType(PrimaryActionPill))).colorScheme.error;
      expect((pill.decoration as ShapeDecoration).color, accent);
    });

    testWidgets('keeps every action inside a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          WallpaperActionBar(
            primary: const WallpaperBarAction(label: 'Set as wallpaper', child: SizedBox(width: 54, height: 54)),
            actions: List<WallpaperBarAction>.generate(
              4,
              (i) => WallpaperBarAction(label: 'a$i', child: const SizedBox(width: 54, height: 54)),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('SimilarWallpapersStrip', () {
    testWidgets('is hidden when nothing similar exists', (tester) async {
      await tester.pumpWidget(
        _host(
          SimilarWallpapersStrip(entity: _wall('a'), loader: (_) async => const <FeedItemEntity>[], onOpen: (_) {}),
        ),
      );
      await tester.pump();

      expect(find.text('More like this'), findsNothing);
    });

    testWidgets('is hidden when loading fails', (tester) async {
      await tester.pumpWidget(
        _host(
          SimilarWallpapersStrip(entity: _wall('a'), loader: (_) async => throw Exception('offline'), onOpen: (_) {}),
        ),
      );
      await tester.pump();

      expect(find.text('More like this'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the walls and reports the tapped one', (tester) async {
      FeedItemEntity? opened;
      await tester.pumpWidget(
        _host(
          SimilarWallpapersStrip(
            entity: _wall('a'),
            loader: (_) async => <FeedItemEntity>[_wall('b'), _wall('c')],
            onOpen: (item) => opened = item,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('More like this'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('c')));
      expect(opened?.id, 'c');
    });
  });

  group('WallpaperTagChips', () {
    testWidgets('tapping a tag reports it', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        _host(WallpaperTagChips(tags: const <String>['space', 'stars'], onTagTap: (tag) => tapped = tag)),
      );

      await tester.tap(find.text('stars'));

      expect(tapped, 'stars');
    });

    testWidgets('renders nothing without tags', (tester) async {
      await tester.pumpWidget(_host(WallpaperTagChips(tags: const <String>[], onTagTap: (_) {})));

      expect(find.byType(ActionChip), findsNothing);
    });
  });

  group('MakeItLiveButton', () {
    testWidgets('appears when the device supports OpenGL live wallpapers', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(_host(MakeItLiveButton(supportProbe: () async => true, onPressed: () => pressed++)));
      await tester.pump();

      await tester.tap(find.text('Make it live'));

      expect(pressed, 1);
    });

    testWidgets('stays hidden when unsupported or when the probe fails', (tester) async {
      await tester.pumpWidget(_host(MakeItLiveButton(supportProbe: () async => false, onPressed: () {})));
      await tester.pump();
      expect(find.text('Make it live'), findsNothing);

      await tester.pumpWidget(
        _host(MakeItLiveButton(key: UniqueKey(), supportProbe: () async => throw Exception('x'), onPressed: () {})),
      );
      await tester.pump();
      expect(find.text('Make it live'), findsNothing);
    });
  });
}
