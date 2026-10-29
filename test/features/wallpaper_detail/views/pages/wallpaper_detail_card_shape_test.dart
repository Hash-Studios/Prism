import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

FeedItemEntity _wall({int? width, int? height}) => FeedItemEntity.pexels(
  id: 'pexels-1',
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: 'pexels-1',
      source: WallpaperSource.pexels,
      fullUrl: 'https://images.example/full.jpg',
      thumbnailUrl: 'https://images.example/thumb.jpg',
      width: width,
      height: height,
    ),
  ),
);

Future<File> _writePng(Directory directory, int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = Colors.teal);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  picture.dispose();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return File('${directory.path}/wall.png')..writeAsBytesSync(bytes.buffer.asUint8List());
}

double _aspect(Size size) => size.width / size.height;

void main() {
  setUpFavouriteCounts();

  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
  });

  tearDown(() => getIt.reset());

  Size card(WidgetTester tester) => tester.getSize(find.byType(WallpaperDetailHero));

  Future<StreamController<WallpaperDetailState>> pumpDetail(
    WidgetTester tester, {
    required WallpaperDetailState initial,
    FeedItemEntity? entity,
    File? localFile,
    bool disableAnimations = false,
  }) async {
    final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>();
    addTearDown(states.close);
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, states.stream, initialState: initial);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(
            entity: entity,
            wallId: entity == null ? 'pexels-1' : null,
            source: entity == null ? WallpaperSource.pexels : null,
            thumbnailUrl: entity == null ? 'https://images.example/thumb.jpg' : null,
            localFile: localFile,
            heroTag: 'tile-1',
          ),
        ),
      ),
    );
    await tester.pump();
    return states;
  }

  testWidgets('a wall opened by id eases to its shape when it loads, without a snap', (tester) async {
    final states = await pumpDetail(tester, initial: const WallpaperDetailLoading());
    final Size opened = card(tester);
    expect(_aspect(opened), lessThan(1));

    states.add(WallpaperDetailLoaded(entity: _wall(width: 1600, height: 900), paletteLoading: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Size midway = card(tester);
    expect(_aspect(midway), greaterThan(_aspect(opened)));
    expect(_aspect(midway), lessThan(16 / 9 - 0.01));

    await tester.pump(const Duration(milliseconds: 400));
    expect(_aspect(card(tester)), closeTo(16 / 9, 0.01));
  });

  testWidgets('with reduce motion on, the card takes its loaded shape at once', (tester) async {
    final states = await pumpDetail(tester, initial: const WallpaperDetailLoading(), disableAnimations: true);

    states.add(WallpaperDetailLoaded(entity: _wall(width: 1600, height: 900), paletteLoading: false));
    await tester.pump();
    await tester.pump();

    expect(_aspect(card(tester)), closeTo(16 / 9, 0.01));
  });

  testWidgets('a wall with no size takes the shape of its painted picture', (tester) async {
    final Directory directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('detail-card-shape-')))!;
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    final File file = (await tester.runAsync(() => _writePng(directory, 160, 90)))!;
    final FeedItemEntity sizeless = _wall();
    await pumpDetail(
      tester,
      initial: WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: sizeless,
        paletteLoading: false,
      ),
      entity: sizeless,
      localFile: file,
    );
    expect(_aspect(card(tester)), lessThan(1));

    for (var i = 0; i < 100 && _aspect(card(tester)) < 1; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(_aspect(card(tester)), closeTo(16 / 9, 0.01));
  });

  testWidgets('a known size wins over the painted picture', (tester) async {
    final Directory directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('detail-card-shape-')))!;
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    final File file = (await tester.runAsync(() => _writePng(directory, 160, 90)))!;
    final FeedItemEntity portrait = _wall(width: 1080, height: 1920);
    await pumpDetail(
      tester,
      initial: WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: portrait,
        paletteLoading: false,
      ),
      entity: portrait,
      localFile: file,
    );
    final Size opened = card(tester);

    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(card(tester), opened);
  });
}
