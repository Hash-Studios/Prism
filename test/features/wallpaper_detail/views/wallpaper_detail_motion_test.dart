import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/favourite_test_scope.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/wallpaper_image_finders.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

void main() {
  setUpFavouriteCounts();
  for (final tag in <String?>['tile-1', null]) {
    testWidgets('reduced-motion detail loading disables flights and fades (tag $tag)', (tester) async {
      final bloc = _MockDetailBloc();
      whenListen(
        bloc,
        const Stream<WallpaperDetailState>.empty(),
        initialState: const WallpaperDetailLoading(
          thumbnailUrl: 'https://prismwalls.com/api/ai/assets/ai/studio/thumb_wall.jpg',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<WallpaperDetailBloc>.value(
              value: bloc,
              child: WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.prism, heroTag: tag),
            ),
          ),
        ),
      );
      if (tag != null) {
        expect(tester.widget<HeroMode>(find.byType(HeroMode)).enabled, isFalse);
      } else {
        expect(find.byType(Hero), findsNothing);
      }
      expect(networkImageUrls(tester), ['https://prismwalls.com/api/ai/assets/ai/studio/thumb_wall.jpg']);
      // No fade under reduced motion: no translucent Opacity wraps the thumbnail.
      final Finder thumbnail = find.byWidgetPredicate(
        (widget) => widget is Image && unwrapImageProvider(widget.image) is CachedNetworkImageProvider,
      );
      expect(
        find.ancestor(
          of: thumbnail,
          matching: find.byWidgetPredicate((widget) => widget is Opacity && widget.opacity < 1),
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a short split-screen window scrolls the loading card and placeholders instead of overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = _MockDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: const WallpaperDetailLoading(
        thumbnailUrl: 'https://prismwalls.com/api/ai/assets/ai/studio/thumb_wall.jpg',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.prism),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Loading wallpaper'), findsOneWidget);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  group('colour variation', () {
    const FeedItemEntity entity = FeedItemEntity.prism(
      id: 'prism-1',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'prism-1',
          source: WallpaperSource.prism,
          fullUrl: 'https://img.test/full.jpg',
          thumbnailUrl: 'https://img.test/thumb.jpg',
        ),
      ),
    );
    const ColorFilter tealHue = ColorFilter.mode(Colors.teal, BlendMode.hue);

    setUp(() {
      getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
      getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    });
    tearDown(getIt.reset);

    Future<StreamController<WallpaperDetailState>> pumpUntinted(
      WidgetTester tester, {
      required bool reduceMotion,
    }) async {
      final bloc = _MockDetailBloc();
      final states = StreamController<WallpaperDetailState>();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: const WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: entity,
          paletteLoading: false,
          colors: <Color>[Colors.teal],
          accent: Colors.teal,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: MediaQuery(
            data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduceMotion),
            child: BlocProvider<WallpaperDetailBloc>.value(
              value: bloc,
              child: const WallpaperDetailScreen(entity: entity),
            ),
          ),
        ),
      );
      await tester.pump();
      return states;
    }

    const WallpaperDetailLoaded tinted = WallpaperDetailLoaded(
      recommendations: const RecommendationState.exhausted(),
      entity: entity,
      paletteLoading: false,
      colors: <Color>[Colors.teal],
      accent: Colors.teal,
      colorChanged: true,
    );

    ColorFilter? shownFilter(WidgetTester tester) {
      final Finder filtered = find.byType(ColorFiltered);
      return filtered.evaluate().isEmpty ? null : tester.widget<ColorFiltered>(filtered).colorFilter;
    }

    testWidgets('with reduced motion the hue is on the wallpaper in the same frame', (tester) async {
      final states = await pumpUntinted(tester, reduceMotion: true);

      states.add(tinted);
      await tester.pump();
      await tester.pump();

      expect(shownFilter(tester), tealHue);
    });

    testWidgets('the hue settles on the colour within a quarter of a second and goes away softly', (tester) async {
      final states = await pumpUntinted(tester, reduceMotion: false);

      states.add(tinted);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final ColorFilter? partway = shownFilter(tester);
      await tester.pump(const Duration(milliseconds: 250));

      expect(partway, isNotNull);
      expect(partway, isNot(tealHue));
      expect(shownFilter(tester), tealHue);

      states.add(tinted.copyWith(colorChanged: false));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(shownFilter(tester), isNot(tealHue));
      await tester.pump(const Duration(milliseconds: 250));

      expect(shownFilter(tester), isNull);
    });

    testWidgets('moving from one colour to another turns the hue round instead of fading through grey', (tester) async {
      final Color red = const HSLColor.fromAHSL(1, 0, 1, 0.5).toColor();
      final Color green = const HSLColor.fromAHSL(1, 160, 1, 0.5).toColor();
      WallpaperDetailLoaded picked(Color color) => tinted.copyWith(colors: <Color>[color], accent: color);
      final states = await pumpUntinted(tester, reduceMotion: false);
      states.add(picked(red));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      states.add(picked(green));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      final double eased = Curves.easeOutCubic.transform(0.5);
      expect(shownFilter(tester), ColorFilter.mode(lerpHueTint(red, green, eased)!, BlendMode.hue));
      expect(shownFilter(tester), isNot(ColorFilter.mode(Color.lerp(red, green, eased)!, BlendMode.hue)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(shownFilter(tester), ColorFilter.mode(green, BlendMode.hue));
    });
  });

  group('lerpHueTint', () {
    HSLColor hsl(Color? color) => HSLColor.fromColor(color!);

    test('blends the hue round the colour wheel and keeps the colour full', () {
      final Color red = const HSLColor.fromAHSL(1, 0, 1, 0.5).toColor();
      final Color green = const HSLColor.fromAHSL(1, 160, 1, 0.5).toColor();

      final Color? midway = lerpHueTint(red, green, 0.5);

      expect(hsl(midway).hue, closeTo(80, 0.5));
      expect(hsl(midway).saturation, closeTo(1, 0.01));
      expect(hsl(midway).lightness, closeTo(0.5, 0.01));
      expect([midway!.r, midway.g, midway.b], [closeTo(0.667, 0.01), closeTo(1, 0.01), closeTo(0, 0.01)]);
    });

    test('takes the short way over the 0 degree seam', () {
      final Color magenta = const HSLColor.fromAHSL(1, 350, 1, 0.5).toColor();
      final Color orange = const HSLColor.fromAHSL(1, 30, 1, 0.5).toColor();

      expect(hsl(lerpHueTint(magenta, orange, 0.5)).hue, closeTo(10, 0.5));
      expect(hsl(lerpHueTint(orange, magenta, 0.25)).hue, closeTo(20, 0.5));
    });

    test('starts at the first colour and ends on the second', () {
      const Color from = Color(0xFF3366CC);
      const Color to = Color(0xFFCC6633);

      expect(lerpHueTint(from, to, 0), from);
      expect(lerpHueTint(from, to, 1), to);
    });

    test('with no tint at one end the other colour fades in or out, and its hue stays', () {
      const Color teal = Color(0xFF008080);

      expect(lerpHueTint(null, teal, 0.25)!.a, closeTo(0.25, 0.01));
      expect(hsl(lerpHueTint(null, teal, 0.25)).hue, closeTo(180, 0.5));
      expect(lerpHueTint(teal, null, 0.25)!.a, closeTo(0.75, 0.01));
      expect(lerpHueTint(null, null, 0.5), isNull);
    });
  });
}
