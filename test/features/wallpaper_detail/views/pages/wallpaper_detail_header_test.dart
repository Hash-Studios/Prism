import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/biz/block_wall_creator.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/profile_user_fixture.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _PendingOfflineAssetStore extends OfflineAssetStore {
  _PendingOfflineAssetStore({required super.directory, required this.lookupResult});

  final Future<File?> lookupResult;

  @override
  Future<File?> lookup(String source) => lookupResult;

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) async {
    final File? file = await lookup(source);
    if (file != null) return file;
    throw OfflineAssetUnavailableException(source);
  }
}

FeedItemEntity _prism({
  String id = 'prism-1',
  String? title,
  String? authorName = 'Akshay',
  String? authorEmail = 'creator@example.com',
  String? docId = 'doc-1',
  int? width,
  int? height,
}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      authorName: authorName,
      authorEmail: authorEmail,
      width: width,
      height: height,
    ),
    title: title,
    firestoreDocumentId: docId,
  ),
);

FeedItemEntity _wallhaven() => const FeedItemEntity.wallhaven(
  id: 'wallhaven-1',
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: 'wallhaven-1',
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      favourites: 24,
    ),
    views: 1234,
    favorites: 24,
  ),
);

Future<void> _waitForCachedImage(WidgetTester tester) async {
  final Stopwatch timeout = Stopwatch()..start();
  while (find.byType(CachedNetworkImage).evaluate().isEmpty && timeout.elapsed < const Duration(seconds: 2)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)).timeout(const Duration(seconds: 2)),
    );
    await tester.pump();
  }
}

void main() {
  setUpFavouriteCounts(counts: const {'PRISM-1': PrismWallpaperStats(favourites: 7, views: 0)});
  late _MockWallpaperDetailBloc bloc;
  late OfflineAssetFixture offlineAssets;

  setUpAll(() => registerFallbackValue(const FetchViews()));

  setUp(() async {
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    app_state.prismUser = profileUser(loggedIn: false);
    bloc = _MockWallpaperDetailBloc();
  });

  tearDown(() async {
    await offlineAssets.dispose();
    await getIt.reset();
  });

  Future<void> pump(
    WidgetTester tester,
    WallpaperDetailState state, {
    FeedItemEntity? entity,
    WallpaperSource source = WallpaperSource.prism,
  }) async {
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: entity, wallId: entity == null ? 'prism-1' : null, source: source),
        ),
      ),
    );
    await tester.pump();
    await _waitForCachedImage(tester);
  }

  group('headline', () {
    testWidgets('shows Prism favourite and known views as paired stats', (tester) async {
      final entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);
      await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('0 views'), findsNothing);
    });

    testWidgets('unknown views are omitted without an inline spinner or duplicate label', (tester) async {
      final entity = _prism(id: 'unknown');
      await pump(
        tester,
        WallpaperDetailLoaded(entity: entity, paletteLoading: false, viewsLoading: true),
        entity: entity,
      );
      await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);
      expect(find.textContaining('views'), findsNothing);
    });

    testWidgets('fresh detail views override cached zero and render without cached stats', (tester) async {
      final entity = _prism();
      await pump(
        tester,
        WallpaperDetailLoaded(entity: entity, paletteLoading: false, views: '1234'),
        entity: entity,
      );
      await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('1.2K'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.text('0 views'), findsNothing);
    });

    testWidgets('fresh views render when favourite stats are unavailable', (tester) async {
      final entity = _prism(id: 'uncached');
      await pump(
        tester,
        WallpaperDetailLoaded(entity: entity, paletteLoading: false, views: '45'),
        entity: entity,
      );
      await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('45'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('7 favourites'), findsNothing);
    });

    testWidgets('Wallhaven metadata keeps favourite and view totals paired', (tester) async {
      final entity = _wallhaven();
      await pump(
        tester,
        WallpaperDetailLoaded(entity: entity, paletteLoading: false),
        entity: entity,
        source: WallpaperSource.wallhaven,
      );
      await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('24'), findsOneWidget);
      expect(find.text('1.2K'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.textContaining('views'), findsNothing);
    });

    testWidgets('a narrow headline keeps the set count while views are unknown', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final entity = _prism(id: 'uncached-narrow', title: 'A long wallpaper title that fills the headline');
      await pump(
        tester,
        WallpaperDetailLoaded(entity: entity, paletteLoading: false, viewsLoading: true, setCount: 12),
        entity: entity,
      );
      await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Set 12 times'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows the title the creator gave, not the id', (tester) async {
      final FeedItemEntity entity = _prism(title: 'Misty pines');
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Misty pines'), findsOneWidget);
      expect(find.text('PRISM-1'), findsNothing);
    });

    testWidgets('falls back to Wallpaper by the creator name', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Wallpaper by Akshay'), findsOneWidget);
    });

    testWidgets('never shows an email as the creator', (tester) async {
      final FeedItemEntity entity = _prism(authorName: 'creator@example.com');
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Wallpaper by Prism creator'), findsOneWidget);
      expect(find.text('Wallpaper by creator@example.com'), findsNothing);
    });

    testWidgets('shows Set N times from 5 sets', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false, setCount: 12), entity: entity);

      expect(find.text('Set 12 times'), findsOneWidget);
    });

    testWidgets('hides the set count below 5 and when unknown', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false, setCount: 4), entity: entity);
      expect(find.textContaining('Set 4'), findsNothing);
      expect(find.textContaining(RegExp(r'Set \d+ times')), findsNothing);

      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);
      expect(find.textContaining(RegExp(r'Set \d+ times')), findsNothing);
    });
  });

  testWidgets('keeps the network image visible while the retained-copy lookup is pending', (tester) async {
    final Completer<File?> lookup = Completer<File?>();
    OfflineAssetStore.testOverride = _PendingOfflineAssetStore(
      directory: Directory('${offlineAssets.directory.path}/pending'),
      lookupResult: lookup.future,
    );
    final FeedItemEntity entity = _prism();
    await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

    final Finder pendingPreview = find.byType(FutureBuilder<File?>);
    expect(find.descendant(of: pendingPreview, matching: find.byType(CachedNetworkImage)), findsNWidgets(2));

    lookup.complete(null);
    await tester.pump();
  });

  group('block creator', () {
    testWidgets("is offered to a signed-in viewer on someone else's wall", (tester) async {
      app_state.prismUser = profileUser();
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block creator'), findsOneWidget);
    });

    testWidgets('is hidden for a guest', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block creator'), findsNothing);
    });

    testWidgets('is hidden on your own wall', (tester) async {
      app_state.prismUser = profileUser();
      final FeedItemEntity entity = _prism(authorEmail: 'User@Example.com');
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Block creator'), findsNothing);
    });

    testWidgets('is hidden when the creator is unknown', (tester) async {
      app_state.prismUser = profileUser();
      final FeedItemEntity entity = _prism(authorEmail: null);
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Block creator'), findsNothing);
    });

    testWidgets('bundled starters do not offer report or creator-block actions', (tester) async {
      app_state.prismUser = profileUser();
      final FeedItemEntity entity = _prism(id: 'starter-sunset', docId: 'bundled-starter-doc');
      expect(BundledWallpapers.isStarter(entity), isTrue);

      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Report'), findsNothing);
      expect(find.text('Block creator'), findsNothing);
      expect(canBlockWallCreator(entity), isFalse);
      await blockWallCreator(tester.element(find.byType(WallpaperDetailScreen)), entity);
    });
  });

  test('starter wallpapers do not record cloud set statistics', () {
    final FeedItemEntity starter = _prism(id: 'starter-sunset', docId: 'bundled-starter-doc');
    final FeedItemEntity cloudWallpaper = _prism();

    expect(shouldRecordWallpaperSetStats(starter), isFalse);
    expect(shouldRecordWallpaperSetStats(cloudWallpaper), isTrue);
  });

  group('load error', () {
    testWidgets('shows a plain message, keeps the thumbnail behind it and loads again on Try again', (tester) async {
      await pump(
        tester,
        const WallpaperDetailError(
          failure: WallpaperDetailLoadFailure.unavailable,
          thumbnailUrl: 'https://img.test/thumb.jpg',
        ),
      );

      expect(find.text("Couldn't load this wallpaper"), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl, 'https://img.test/thumb.jpg');

      await tester.tap(find.text('Try again'));
      await tester.pump();
      verify(() => bloc.add(any(that: isA<LoadFromId>()))).called(2);
    });

    testWidgets('a missing wallpaper keeps the not found message', (tester) async {
      await pump(tester, const WallpaperDetailError(failure: WallpaperDetailLoadFailure.notFound));

      expect(find.text('Wallpaper not found'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });

  group('Live chip', () {
    testWidgets('shows a tappable glass Live pill with a 48 px touch target when the device supports live walls', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: MakeItLiveChip(onPressed: () => opened++, supportProbe: () async => true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Live'), findsOneWidget);
      expect(tester.getSize(find.byType(PrismGlass)).height, 32);
      final Size target = tester.getSize(
        find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(GestureDetector)),
      );
      expect(target.height, 48);
      expect(target.width, inInclusiveRange(48, 150));
      await tester.tap(find.bySemanticsLabel('Make it live'));
      expect(opened, 1);
    });

    testWidgets('shrinks a little under the finger', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: MakeItLiveChip(onPressed: () {}, supportProbe: () async => true),
          ),
        ),
      );
      await tester.pump();
      double scale() => tester
          .widget<Transform>(find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(Transform)).first)
          .transform
          .storage[0];

      final TestGesture finger = await tester.startGesture(tester.getCenter(find.byType(PrismGlass)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final double pressed = scale();
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(pressed, closeTo(0.96, 0.001));
      expect(scale(), 1);
    });

    Future<void> pumpChip(
      WidgetTester tester, {
      double textScale = 1,
      bool reduceMotion = false,
      Brightness brightness = Brightness.dark,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          themeAnimationDuration: Duration.zero,
          theme: ThemeData(brightness: brightness, primaryColor: const Color(0xFF204060)),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: MakeItLiveChip(onPressed: () {}, supportProbe: () async => true),
          ),
        ),
      );
      await tester.pump();
    }

    double chipOpacity(WidgetTester tester) => tester
        .widget<Opacity>(find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(Opacity)).first)
        .opacity;

    testWidgets('fades in over 160 ms when the probe answers, instead of popping in', (tester) async {
      await pumpChip(tester);
      final double first = chipOpacity(tester);

      await tester.pump(const Duration(milliseconds: 80));
      final double midway = chipOpacity(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(first, 0);
      expect(midway, inExclusiveRange(0.3, 0.95));
      expect(chipOpacity(tester), 1);
    });

    testWidgets('shows at once when the device asks for less motion', (tester) async {
      await pumpChip(tester, reduceMotion: true);

      expect(chipOpacity(tester), 1);
    });

    testWidgets('its label scales with the system text only up to 1.5 times, and the pill follows the label', (
      tester,
    ) async {
      final Map<double, Size> pill = <double, Size>{};
      for (final double scale in <double>[1, 1.5, 2]) {
        await pumpChip(tester, textScale: scale);
        await tester.pump(const Duration(milliseconds: 200));
        pill[scale] = tester.getSize(find.byType(PrismGlass));
      }

      expect(pill[1.5]!.width, greaterThan(pill[1]!.width));
      expect(pill[2], pill[1.5]);
      expect(pill[2]!.height, 32);
    });

    testWidgets('sits on a dark scrim with white text, on a light theme as on a dark one', (tester) async {
      for (final Brightness brightness in <Brightness>[Brightness.dark, Brightness.light]) {
        await pumpChip(tester, brightness: brightness);
        final PrismGlass glass = tester.widget<PrismGlass>(find.byType(PrismGlass));

        expect(glass.glassColor, Colors.black.withValues(alpha: 0.5));
        expect(glass.thickness, 16);
        expect(tester.widget<Text>(find.text('Live')).style?.color, Colors.white);
      }
    });

    testWidgets('stays hidden when the device does not support live wallpapers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: MakeItLiveChip(onPressed: () {}, supportProbe: () async => false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Live'), findsNothing);
    });
  });

  testWidgets('the panel lists the landscape note for a wide wall', (tester) async {
    final FeedItemEntity entity = _prism(width: 4000, height: 2000);
    await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

    expect(find.text('Landscape wallpaper: the sides will be cropped'), findsOneWidget);
  });
}
