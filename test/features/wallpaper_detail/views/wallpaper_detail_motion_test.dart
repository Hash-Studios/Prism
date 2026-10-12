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
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

void main() {
  for (final tag in <String?>['tile-1', null]) {
    testWidgets('reduced-motion detail loading disables flights and fades (tag $tag)', (tester) async {
      final bloc = _MockDetailBloc();
      whenListen(
        bloc,
        const Stream<WallpaperDetailState>.empty(),
        initialState: const WallpaperDetailLoading(thumbnailUrl: 'https://example.com/thumb.jpg'),
      );
      await tester.pumpWidget(
        MaterialApp(
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
      final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.fadeInDuration, Duration.zero);
      expect(image.fadeOutDuration, Duration.zero);
      await tester.pumpWidget(const SizedBox());
    });
  }

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
          entity: entity,
          paletteLoading: false,
          colors: <Color>[Colors.teal],
          accent: Colors.teal,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
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
  });
}
