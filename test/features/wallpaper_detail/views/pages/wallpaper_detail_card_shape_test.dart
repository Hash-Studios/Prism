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
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

FeedItemEntity _wall({String id = 'pexels-1', int? width, int? height}) => FeedItemEntity.pexels(
  id: id,
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.pexels,
      fullUrl: 'https://images.example/$id.jpg',
      thumbnailUrl: 'https://images.example/$id-thumb.jpg',
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
    ValueNotifier<bool>? motionPreference,
  }) async {
    final ValueNotifier<bool> motion = motionPreference ?? ValueNotifier<bool>(disableAnimations);
    if (motionPreference == null) addTearDown(motion.dispose);
    final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>();
    addTearDown(states.close);
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, states.stream, initialState: initial);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: motion,
          builder: (context, disable, _) => favouriteTestBuilder(
            context,
            MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: disable),
              child: child!,
            ),
          ),
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
    final Rect imageRect = tester.getRect(find.byType(WallpaperDetailHero));
    final Rect backRect = tester.getRect(find.byTooltip('Back'));
    expect(backRect.left, closeTo(imageRect.left + 4, 1));

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

  testWidgets('status bar fade follows the visible card while its shape eases', (tester) async {
    final FeedItemEntity sizeless = _wall();
    final List<FeedItemEntity> recommendations = <FeedItemEntity>[
      for (var i = 0; i < 12; i++) _wall(id: 'recommendation-$i', width: 900, height: 1600),
    ];
    final RecommendationState recommendationState = RecommendationState(
      items: recommendations,
      status: RecommendationStatus.ready,
    );
    final StreamController<WallpaperDetailState> states = await pumpDetail(
      tester,
      initial: WallpaperDetailLoaded(
        recommendations: recommendationState,
        entity: sizeless,
        paletteLoading: false,
        accent: Colors.black,
      ),
    );
    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.maxScrollExtent, greaterThan(370));
    position.jumpTo(370);
    await tester.pump();

    states.add(
      WallpaperDetailLoaded(
        entity: _wall(width: 1600, height: 900),
        paletteLoading: false,
        accent: Colors.black,
        recommendations: recommendationState,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(card(tester).height, greaterThan(position.pixels));

    final AnimatedOpacity fade = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('detail-status-fade')),
    );
    expect(fade.opacity, 0, reason: 'the card still extends below the status bar during its shape morph');
    SystemUiOverlayStyle overlay() =>
        tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(find.byType(AnnotatedRegion<SystemUiOverlayStyle>)).value;
    expect(overlay().statusBarIconBrightness, Brightness.light);

    await tester.pump(const Duration(milliseconds: 400));
    final AnimatedOpacity settledFade = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('detail-status-fade')),
    );
    expect(settledFade.opacity, 1, reason: 'the feed is below the now-shorter card');
    expect(overlay().statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('a viewport resize eases from the card size already on screen', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FeedItemEntity landscape = _wall(width: 1600, height: 900);
    await pumpDetail(
      tester,
      initial: WallpaperDetailLoaded(entity: landscape, paletteLoading: false),
      entity: landscape,
    );
    final Size opened = card(tester);

    tester.view.physicalSize = const Size(800, 600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Size midway = card(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final Size settled = card(tester);

    expect(midway.width, greaterThan(opened.width));
    expect(midway.width, lessThan(settled.width));
    expect(settled.width, greaterThan(opened.width));
  });

  testWidgets('turning reduce motion on mid-morph takes the current target at once', (tester) async {
    final ValueNotifier<bool> motionPreference = ValueNotifier<bool>(false);
    addTearDown(motionPreference.dispose);
    final StreamController<WallpaperDetailState> states = await pumpDetail(
      tester,
      initial: const WallpaperDetailLoading(),
      motionPreference: motionPreference,
    );
    states.add(WallpaperDetailLoaded(entity: _wall(width: 1600, height: 900), paletteLoading: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_aspect(card(tester)), lessThan(16 / 9 - 0.01));

    motionPreference.value = true;
    await tester.pump();
    await tester.pump();

    expect(_aspect(card(tester)), closeTo(16 / 9, 0.01));
    expect(tester.takeException(), isNull);
  });
}
