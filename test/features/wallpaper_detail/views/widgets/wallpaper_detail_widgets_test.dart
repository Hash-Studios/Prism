import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_recommendations.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_tag_chips.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: favouriteTestBuilder,
  home: Scaffold(body: child),
);

const List<String> _tagThemes = <String>['Frost White', 'Cotton Blue', 'AMOLED'];

void main() {
  setUpFavouriteCounts();
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

    testWidgets('shows a caption under each icon action, not under the primary action', (tester) async {
      await tester.pumpWidget(
        _host(
          const WallpaperActionBar(
            primary: WallpaperBarAction(label: 'Set as wallpaper', child: Text('Set')),
            secondary: <WallpaperBarAction>[
              WallpaperBarAction(
                label: 'Download',
                child: CircularMenuButton(label: 'Download', isLoading: false, child: Icon(Icons.download)),
              ),
            ],
            actions: <WallpaperBarAction>[
              WallpaperBarAction(
                label: 'Share',
                child: CircularMenuButton(label: 'Share', isLoading: false, child: Icon(Icons.share)),
              ),
              WallpaperBarAction(
                label: 'Remix this wallpaper with AI',
                caption: 'Remix',
                child: CircularMenuButton(label: 'Remix', isLoading: false, child: Icon(Icons.brush)),
              ),
            ],
          ),
        ),
      );

      for (final (String caption, IconData icon) in <(String, IconData)>[
        ('Share', Icons.share),
        ('Remix', Icons.brush),
        ('Download', Icons.download),
      ]) {
        expect(find.text(caption), findsOneWidget, reason: caption);
        expect(tester.widget<Text>(find.text(caption)).style!.fontSize, greaterThanOrEqualTo(12));
        expect(tester.getRect(find.text(caption)).top, greaterThan(tester.getRect(find.byIcon(icon)).bottom));
        expect(tester.getCenter(find.text(caption)).dx, closeTo(tester.getCenter(find.byIcon(icon)).dx, 0.5));
      }
      expect(find.text('Remix this wallpaper with AI'), findsNothing);
      expect(find.text('Set as wallpaper'), findsNothing);
      expect(tester.getSize(find.byType(WallpaperActionBar)).height, WallpaperActionBar.height);
    });

    for (final double textScale in <double>[1, 2]) {
      testWidgets('the full caption is tappable at ${textScale}x text', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: WallpaperActionBar(
                primary: const WallpaperBarAction(label: 'Set as wallpaper', child: Text('Set')),
                actions: <WallpaperBarAction>[
                  WallpaperBarAction(
                    label: 'Share',
                    child: CircularMenuButton(
                      label: 'Share',
                      isLoading: false,
                      onTap: () => taps++,
                      child: const Icon(Icons.share),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final Rect caption = tester.getRect(find.text('Share'));
        final Rect target = tester.getRect(find.byType(CircularMenuButton));
        expect(target.contains(caption.bottomCenter - const Offset(0, 1)), isTrue);
        await tester.tapAt(Offset(caption.center.dx, caption.bottom - 1));
        expect(taps, 1);
      });
    }

    testWidgets('draws menu buttons bare and the primary action as an accent pill', (tester) async {
      await tester.pumpWidget(
        _host(
          const WallpaperActionBar(
            primary: WallpaperBarAction(
              label: 'Set as wallpaper',
              child: PrimaryActionPill(label: 'Set', semanticLabel: 'Set as wallpaper', isLoading: false),
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
      final Color accent = Theme.of(tester.element(find.byType(PrimaryActionPill))).colorScheme.primary;
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

    testWidgets('keeps icon actions at least 44 points wide with large text on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: WallpaperActionBar(
              primary: WallpaperBarAction(
                label: 'Set as wallpaper',
                child: PrimaryActionPill(label: 'Set', semanticLabel: 'Set as wallpaper', isLoading: false),
              ),
              actions: <WallpaperBarAction>[
                WallpaperBarAction(
                  label: 'Download',
                  child: CircularMenuButton(label: 'Download', isLoading: false, child: Icon(Icons.download)),
                ),
                WallpaperBarAction(
                  label: 'Favourite',
                  child: CircularMenuButton(label: 'Favourite', isLoading: false, child: Icon(Icons.favorite)),
                ),
                WallpaperBarAction(
                  label: 'Share',
                  child: CircularMenuButton(label: 'Share', isLoading: false, child: Icon(Icons.share)),
                ),
                WallpaperBarAction(
                  label: 'Edit',
                  child: CircularMenuButton(label: 'Edit', isLoading: false, child: Icon(Icons.edit)),
                ),
              ],
            ),
          ),
        ),
      );

      final SemanticsHandle semantics = tester.ensureSemantics();
      for (final String label in <String>['Download', 'Favourite', 'Share', 'Edit']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)).rect.width,
          greaterThanOrEqualTo(44),
          reason: '$label tap target',
        );
      }
      semantics.dispose();
    });
  });

  group('FlatMenuButtons', () {
    Future<void> pumpRow(WidgetTester tester, Widget row) => tester.pumpWidget(_host(Center(child: row)));
    double iconSize(WidgetTester tester, String label) => IconTheme.of(
      tester.element(find.descendant(of: find.bySemanticsLabel(label), matching: find.byType(Icon))),
    ).size!;
    Size target(WidgetTester tester, String label) => tester.getSize(
      find.ancestor(of: find.bySemanticsLabel(label), matching: find.byType(CircularMenuButton)).first,
    );

    testWidgets('a plain flat row keeps the old 20 point icon and 17 point padding', (tester) async {
      await pumpRow(
        tester,
        const FlatMenuButtons(
          child: CircularMenuButton(label: 'Share', isLoading: false, child: Icon(Icons.share)),
        ),
      );
      expect(iconSize(tester, 'Share'), 20);
      expect(target(tester, 'Share'), const Size.square(54));
    });

    testWidgets('the detail row sets 24 and 13 points, and a button that sets its own padding keeps it', (
      tester,
    ) async {
      await pumpRow(
        tester,
        const FlatMenuButtons(
          iconSize: 24,
          padding: EdgeInsets.all(13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularMenuButton(label: 'Share', isLoading: false, child: Icon(Icons.share)),
              CircularMenuButton(label: 'Edit', isLoading: false, padding: EdgeInsets.zero, child: Icon(Icons.edit)),
            ],
          ),
        ),
      );
      expect(iconSize(tester, 'Share'), 24);
      expect(target(tester, 'Share'), const Size.square(50));
      expect(target(tester, 'Edit'), const Size.square(24));
    });

    testWidgets('outside a flat row the round button ignores padding and stays a 48 point circle', (tester) async {
      await pumpRow(tester, const CircularMenuButton(label: 'Share', isLoading: false, child: Icon(Icons.share)));
      expect(target(tester, 'Share'), const Size.square(CircularMenuButton.size));
    });
  });

  group('WallpaperRecommendations', () {
    Future<void> pumpRecommendations(WidgetTester tester, RecommendationState state, {VoidCallback? onLoadMore}) =>
        tester.pumpWidget(
          _host(
            CustomScrollView(
              slivers: [
                WallpaperRecommendations(
                  state: state,
                  heroScope: 'test-visit',
                  onOpen: (_, _, _) {},
                  onLoadMore: onLoadMore ?? () {},
                ),
              ],
            ),
          ),
        );

    testWidgets('successful exhausted empty results leave no orphan heading or footer', (tester) async {
      await pumpRecommendations(tester, const RecommendationState.exhausted());
      expect(find.byType(Text), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('initial loading shows tile placeholders and failed empty results can retry', (tester) async {
      await pumpRecommendations(tester, const RecommendationState.initial());
      expect(find.byType(PulseFill), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      var retries = 0;
      await pumpRecommendations(tester, const RecommendationState.initial().failure(), onLoadMore: () => retries++);
      expect(find.byType(PulseFill), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byType(TextButton));
      expect(retries, 1);
    });

    testWidgets('recommendations are image-only tiles that keep the image aspect ratio', (tester) async {
      final item = WallhavenFeedItem(
        id: 'stats-wall',
        wallpaper: WallhavenWallpaper(
          core: WallpaperCore(
            id: 'stats-wall',
            source: WallpaperSource.wallhaven,
            thumbnailUrl: '',
            fullUrl: '',
            favourites: 24,
          ),
          views: 1234,
        ),
      );
      final semantics = tester.ensureSemantics();
      await pumpRecommendations(tester, RecommendationState(items: [item], status: RecommendationStatus.exhausted));
      expect(find.byType(FavouriteWallpaperCard), findsOneWidget);
      // Tiles are image only. Favourite lives in the hold menu, counts on the detail screen.
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
      expect(find.text('24'), findsNothing);
      expect(find.text('1.2K'), findsNothing);
      expect(find.bySemanticsLabel(AppLocalizationsEn().wallpaperViewCount(1234)), findsNothing);
      final image = tester.getRect(find.byType(PrismWallTile));
      expect(image.width / image.height, closeTo(0.5, 0.001));
      semantics.dispose();
    });

    testWidgets('append retry retains tiles and protected Prism tiles never use original fallback', (tester) async {
      final item = PrismFeedItem(
        id: 'protected',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'protected',
            source: WallpaperSource.prism,
            thumbnailUrl: '',
            fullUrl: 'https://protected.test/original.jpg',
          ),
        ),
      );
      var retries = 0;
      await pumpRecommendations(
        tester,
        RecommendationState(items: [item], status: RecommendationStatus.failure),
        onLoadMore: () => retries++,
      );
      expect(tester.widget<PrismWallTile>(find.byType(PrismWallTile)).fallbackUrl, isNull);
      await tester.tap(find.byType(TextButton));
      expect(retries, 1);
      expect(find.byKey(ValueKey((WallpaperSource.prism, 'protected'))), findsOneWidget);
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

      expect(find.byType(PrismChip), findsNothing);
    });

    testWidgets('shows eight tags, then a "+N" chip that shows the rest', (tester) async {
      final List<String> tags = <String>[for (int i = 1; i <= 10; i++) 'tag$i'];
      await tester.pumpWidget(_host(WallpaperTagChips(tags: tags, onTagTap: (_) {})));

      expect(find.byType(PrismChip), findsNWidgets(9));
      expect(find.text('tag8'), findsOneWidget);
      expect(find.text('tag9'), findsNothing);
      expect(find.byTooltip('See more'), findsOneWidget);

      await tester.tap(find.text('+2'));
      await tester.pump();
      expect(find.text('+2'), findsNothing);
      expect(find.byType(PrismChip), findsNWidgets(10));
      expect(find.text('tag10'), findsOneWidget);
    });

    testWidgets('eight tags or fewer show no "+N" chip', (tester) async {
      final List<String> tags = <String>[for (int i = 1; i <= 8; i++) 'tag$i'];
      await tester.pumpWidget(_host(WallpaperTagChips(tags: tags, onTagTap: (_) {})));

      expect(find.byType(PrismChip), findsNWidgets(8));
      expect(find.textContaining('+'), findsNothing);
    });

    for (final String themeName in _tagThemes) {
      testWidgets('$themeName tags are compact readable pills with a 44 point target on the page', (tester) async {
        final PrismThemeOption option = <PrismThemeOption>[
          ...prismLightThemes,
          ...prismDarkThemes,
        ].firstWhere((PrismThemeOption o) => prismThemeDisplayName(o, AppLocalizationsEn()) == themeName);
        final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            home: Scaffold(
              body: WallpaperTagChips(tags: const <String>['space', 'stars'], onTagTap: (_) {}),
            ),
          ),
        );

        for (final String tag in <String>['space', 'stars']) {
          final Finder chip = find.widgetWithText(PrismChip, tag);
          final Finder pill = find.descendant(of: chip, matching: find.byType(AnimatedContainer));
          final BoxDecoration decoration = tester.widget<AnimatedContainer>(pill).decoration! as BoxDecoration;
          final Color fill = Color.alphaBlend(decoration.color!, theme.scaffoldBackgroundColor);
          final Color label = tester
              .widget<RichText>(find.descendant(of: chip, matching: find.byType(RichText)))
              .text
              .style!
              .color!;
          expect(contrastRatio(label, fill), greaterThanOrEqualTo(4.5), reason: tag);
          expect(tester.getSize(pill).height, 34, reason: tag);
          expect(tester.getSize(chip).height, greaterThanOrEqualTo(44), reason: tag);
        }
      });
    }
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
