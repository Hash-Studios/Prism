import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/personalization/personalized_feed_settings.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/photo_search_service.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:Prism/features/user_search/views/widgets/photo_search_chip.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';
import '../creator_directory/creator_directory_test_support.dart';

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

class _MockPhotoSearchService extends Mock implements PhotoSearchService {}

class _MockSearchDiscoveryBloc extends MockBloc<SearchDiscoveryEvent, SearchDiscoveryState>
    implements SearchDiscoveryBloc {}

final AppLocalizationsEn en = AppLocalizationsEn();

Uint8List _preview() =>
    base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

PhotoQuery _photo({PhotoLabelsStatus status = PhotoLabelsStatus.guest, List<String> labels = const <String>[]}) =>
    PhotoQuery(
      preview: _preview(),
      palette: <PaletteShare>[(color: paletteColorById('orange')!, share: 1.0)],
      labels: labels,
      labelsStatus: status,
    );

FeedItemEntity _pexels(String id) => PexelsFeedItem(
  id: id,
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.pexels, fullUrl: '', thumbnailUrl: '', authorName: id),
  ),
);

FeedItemEntity _prism(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  ),
);

WallpaperSearchPage _page(
  List<FeedItemEntity> results, {
  SearchProviderValue provider = SearchProviderValue.wallhaven,
  List<FeedItemEntity> prismResults = const <FeedItemEntity>[],
}) => (provider: provider, results: results, prismResults: prismResults, isLocal: false);

void main() {
  setUpFavouriteCounts();
  late _MockWallpaperSearchService service;
  late _MockPhotoSearchService photos;
  late InMemoryLocalStore store;
  late FakeAppAnalytics analytics;
  late _MockSearchDiscoveryBloc discoveryBloc;

  setUpAll(() {
    registerFallbackValue(const SearchFilters());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(_photo());
  });

  void stubDiscovery(SearchDiscoveryState state) {
    discoveryBloc = _MockSearchDiscoveryBloc();
    when(() => discoveryBloc.state).thenReturn(state);
    whenListen(discoveryBloc, const Stream<SearchDiscoveryState>.empty(), initialState: state);
    getIt.registerFactory<SearchDiscoveryBloc>(() => discoveryBloc);
  }

  setUp(() {
    service = _MockWallpaperSearchService();
    photos = _MockPhotoSearchService();
    store = InMemoryLocalStore();
    getIt
      ..registerSingleton<WallpaperSearchService>(service)
      ..registerSingleton<PhotoSearchService>(photos)
      ..registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store));
    stubDiscovery(SearchDiscoveryState.initial());
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    registerCreatorDirectoryFakes();
    app_state.prismUser = app_constants.createGuestPrismUser();

    when(() => photos.pick()).thenAnswer((_) async => Uint8List.fromList(<int>[1, 2, 3]));
    when(() => photos.queryFor(any(), signedIn: any(named: 'signedIn'))).thenAnswer((_) async => _photo());
    when(
      () => service.searchByPhoto(any(), filters: any(named: 'filters')),
    ).thenAnswer((_) async => (page: _page(<FeedItemEntity>[_pexels('x1')]), query: 'sunset'));
    when(
      () => service.search(any(), filters: any(named: 'filters')),
    ).thenAnswer((_) async => _page(<FeedItemEntity>[]));
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.reset();
    toasts.overlayResolver = null;
    await getIt.reset();
  });

  /// Bounded settle. The discovery skeleton animates forever, so pumpAndSettle would never return.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> pumpScreen(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: favouriteTestBuilder(context, child),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SearchScreen(),
      ),
    );
    await tester.pump();
  }

  /// Signed-in user who has already seen the privacy sheet, then picks a photo that Cloud Vision labels.
  Future<void> pickSignedInPhotoWithLabels(WidgetTester tester, {double textScale = 1.0}) async {
    app_state.prismUser = profileUser();
    when(
      () => photos.queryFor(any(), signedIn: true),
    ).thenAnswer((_) async => _photo(status: PhotoLabelsStatus.found, labels: const <String>['Sunset', 'Sky']));
    await pumpScreen(tester, textScale: textScale);
    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);
    await tester.tap(find.text(en.searchPhotoChoose));
    await settle(tester);
  }

  testWidgets('the search bar has a Search by photo button', (tester) async {
    await pumpScreen(tester);

    expect(find.byTooltip('Search by photo'), findsOneWidget);
    expect(find.byIcon(Icons.image_search_rounded), findsOneWidget);
  });

  testWidgets('a guest picks a photo and sees colour matches with the guest note', (tester) async {
    when(() => photos.queryFor(any(), signedIn: false)).thenAnswer((_) async => _photo());
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    verify(() => photos.queryFor(any(), signedIn: false)).called(1);
    expect(find.text(en.searchPhotoChoose), findsNothing);
    expect(find.text(en.searchPhotoColourMatches), findsOneWidget);
    expect(find.text(en.searchPhotoGuestNote), findsOneWidget);
    expect(analytics.events.whereType<PhotoSearchStartedEvent>().single.signedIn, isFalse);
  });

  testWidgets('a signed-in user sees the privacy sheet once, then labels', (tester) async {
    app_state.prismUser = profileUser();
    when(
      () => photos.queryFor(any(), signedIn: true),
    ).thenAnswer((_) async => _photo(status: PhotoLabelsStatus.found, labels: const <String>['Sunset', 'Sky']));
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);
    expect(find.text(en.searchPhotoPrivacy), findsOneWidget);

    await tester.tap(find.text(en.searchPhotoChoose));
    await settle(tester);

    expect(find.text(en.searchPhotoMatchesFor('sunset, sky')), findsOneWidget);
    expect(find.text(en.searchPhotoSentNote), findsOneWidget);
    expect(analytics.events.whereType<PhotoSearchLabelsReturnedEvent>().single.labelCount, 2);
    expect(
      getIt<SettingsLocalDataSource>().get<bool>(PersistenceKeys.photoSearchPrivacySeen, defaultValue: false),
      isTrue,
    );

    await tester.tap(find.text(en.searchPhotoClear));
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsNothing);
    expect(find.text(en.searchPhotoMatchesFor('sunset, sky')), findsNothing);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    expect(find.text(en.searchPhotoPrivacy), findsNothing);
    verify(() => photos.pick()).called(2);
  });

  testWidgets('the capped note shows the daily limit and tracks the capped event', (tester) async {
    app_state.prismUser = profileUser();
    await getIt<SettingsLocalDataSource>().set(PersistenceKeys.photoSearchPrivacySeen, true);
    when(
      () => photos.queryFor(any(), signedIn: true),
    ).thenAnswer((_) async => _photo(status: PhotoLabelsStatus.capped));
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    expect(find.text(en.searchPhotoCappedNote(20)), findsOneWidget);
    expect(analytics.events.whereType<PhotoSearchLabelsCappedEvent>(), hasLength(1));
  });

  testWidgets('results order: From Prism row first, then the grid', (tester) async {
    when(() => service.searchByPhoto(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        page: _page(
          <FeedItemEntity>[_pexels('x1'), _pexels('x2')],
          prismResults: <FeedItemEntity>[_prism('p1'), _prism('p2')],
        ),
        query: 'sunset',
      ),
    );
    await pickSignedInPhotoWithLabels(tester);

    final double headerTop = tester.getTopLeft(find.text(en.accountFromPrism)).dy;
    final double firstGridTileTop = tester
        .getTopLeft(find.descendant(of: find.byType(SliverGrid), matching: find.byType(PrismWallTile)).first)
        .dy;
    expect(headerTop, lessThan(firstGridTileTop));

    final SearchGrid grid = tester.widget<SearchGrid>(find.byType(SearchGrid));
    expect(grid.fromPhoto, isTrue);
    expect(grid.query, 'sunset');
  });

  testWidgets('no matches shows the photo empty state', (tester) async {
    when(
      () => service.searchByPhoto(any(), filters: any(named: 'filters')),
    ).thenAnswer((_) async => (page: _page(const <FeedItemEntity>[]), query: 'sunset'));
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    expect(find.text(en.searchPhotoNoMatches), findsOneWidget);
    expect(find.text(en.searchPhotoChooseAnother), findsOneWidget);
  });

  testWidgets('large text does not overflow', (tester) async {
    await pickSignedInPhotoWithLabels(tester, textScale: 2.0);

    expect(tester.takeException(), isNull);
    expect(find.byType(PhotoSearchChip), findsOneWidget);
    expect(find.text(en.searchPhotoMatchesFor('sunset, sky')), findsOneWidget);
  });

  testWidgets('pick cancelled does nothing', (tester) async {
    when(() => photos.pick()).thenAnswer((_) async => null);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    verifyNever(() => photos.queryFor(any(), signedIn: any(named: 'signedIn')));
    expect(find.byType(SearchGrid), findsNothing);
    expect(find.text('Find creators'), findsOneWidget);
  });

  testWidgets('filters applied while photo labels are loading do not cancel the photo search', (tester) async {
    final Completer<PhotoQuery> query = Completer<PhotoQuery>();
    when(() => photos.queryFor(any(), signedIn: false)).thenAnswer((_) => query.future);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await tester.pump();
    await tester.tap(find.byTooltip(en.accountFilters));
    await settleSheet(tester);
    await tester.tap(find.text('1440p'));
    await tester.tap(find.text('Apply'));
    await settleSheet(tester);

    query.complete(_photo());
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsOneWidget);
    verify(() => service.searchByPhoto(any(), filters: const SearchFilters(minResolution: '1440x2560'))).called(1);
  });

  testWidgets('cancelling a second picker preserves filters for the first photo still being decoded', (tester) async {
    final Completer<PhotoQuery> query = Completer<PhotoQuery>();
    var picks = 0;
    when(() => photos.pick()).thenAnswer((_) async {
      picks++;
      return picks == 1 ? Uint8List.fromList(<int>[1, 2, 3]) : null;
    });
    when(() => photos.queryFor(any(), signedIn: false)).thenAnswer((_) => query.future);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await tester.pump();
    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);
    await tester.tap(find.byTooltip(en.accountFilters));
    await settleSheet(tester);
    await tester.tap(find.text('1440p'));
    await tester.tap(find.text('Apply'));
    await settleSheet(tester);
    query.complete(_photo());
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsOneWidget);
    verify(() => service.searchByPhoto(any(), filters: const SearchFilters(minResolution: '1440x2560'))).called(1);
  });

  testWidgets('a filtered photo result query is not overwritten by the older in-flight result', (tester) async {
    final Completer<({WallpaperSearchPage page, String query})> first =
        Completer<({WallpaperSearchPage page, String query})>();
    var calls = 0;
    when(() => service.searchByPhoto(any(), filters: any(named: 'filters'))).thenAnswer((_) {
      calls++;
      if (calls == 1) return first.future;
      return Future.value((page: _page(<FeedItemEntity>[_pexels('new')]), query: 'filtered-query'));
    });
    await pumpScreen(tester);
    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);
    await tester.tap(find.byTooltip(en.accountFilters));
    await settleSheet(tester);
    await tester.tap(find.text('1440p'));
    await tester.tap(find.text('Apply'));
    await settleSheet(tester);

    first.complete((page: _page(<FeedItemEntity>[_pexels('old')]), query: 'old-query'));
    await settle(tester);

    expect(tester.widget<SearchGrid>(find.byType(SearchGrid)).query, 'filtered-query');
  });

  testWidgets('a later text search supersedes photo decoding', (tester) async {
    final Completer<PhotoQuery> query = Completer<PhotoQuery>();
    when(() => photos.queryFor(any(), signedIn: false)).thenAnswer((_) => query.future);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'forest');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    query.complete(_photo());
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsNothing);
    verify(() => service.search('forest', filters: any(named: 'filters'))).called(1);
  });

  testWidgets('a photo picker result arriving after a text search cannot replace it', (tester) async {
    final Completer<Uint8List?> picked = Completer<Uint8List?>();
    when(() => photos.pick()).thenAnswer((_) => picked.future);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'forest');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    picked.complete(Uint8List.fromList(<int>[1, 2, 3]));
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsNothing);
    verifyNever(() => photos.queryFor(any(), signedIn: any(named: 'signedIn')));
    verify(() => service.search('forest', filters: any(named: 'filters'))).called(1);
  });

  testWidgets('a feed setting change reruns an active photo search instead of clearing it', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    await getIt<SettingsLocalDataSource>().set(AiContentFilter.settingKey, false);
    personalizedFeedSettingsRevision.value++;
    await tester.pump();

    expect(find.byType(PhotoSearchChip), findsOneWidget);
    verify(() => service.searchByPhoto(any(), filters: any(named: 'filters'))).called(2);
  });

  testWidgets('back while photo labels are loading clears the pending photo search', (tester) async {
    final Completer<PhotoQuery> query = Completer<PhotoQuery>();
    when(() => photos.queryFor(any(), signedIn: false)).thenAnswer((_) => query.future);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    query.complete(_photo());
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsNothing);
    expect(find.byType(SearchGrid), findsNothing);
  });

  testWidgets('clearing a photo while external results load returns to Discover', (tester) async {
    final Completer<({WallpaperSearchPage page, String query})> results =
        Completer<({WallpaperSearchPage page, String query})>();
    when(() => service.searchByPhoto(any(), filters: any(named: 'filters'))).thenAnswer((_) => results.future);
    await pumpScreen(tester);
    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsOneWidget);
    await tester.tap(find.text(en.searchPhotoClear));
    await settle(tester);
    results.complete((page: _page(<FeedItemEntity>[_pexels('late')]), query: 'sunset'));
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsNothing);
    expect(find.byType(SearchGrid), findsNothing);
    expect(find.text('Find creators'), findsOneWidget);
  });

  testWidgets('retrying photo results keeps the selected photo without decoding it again', (tester) async {
    var calls = 0;
    when(() => service.searchByPhoto(any(), filters: any(named: 'filters'))).thenAnswer((_) {
      calls++;
      if (calls == 1) throw const WallpaperSearchException('temporary failure');
      return Future.value((page: _page(<FeedItemEntity>[_pexels('retry')]), query: 'sunset'));
    });
    await pumpScreen(tester);
    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    expect(find.text(en.accountTryAgain), findsOneWidget);
    await tester.tap(find.text(en.accountTryAgain));
    await settle(tester);

    expect(find.byType(PhotoSearchChip), findsOneWidget);
    expect(find.byType(SearchGrid), findsOneWidget);
    verify(() => photos.queryFor(any(), signedIn: false)).called(1);
    expect(calls, 2);
  });

  testWidgets('photo pagination uses the fallback query and top photo colour', (tester) async {
    final SearchFilters expectedFilters = SearchFilters(color: paletteColorById('orange'));
    when(
      () => service.searchByPhoto(any(), filters: any(named: 'filters')),
    ).thenAnswer((_) async => (page: _page(<FeedItemEntity>[for (int i = 0; i < 24; i++) _pexels('x$i')]), query: ''));
    await pumpScreen(tester);
    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    final SearchGrid grid = tester.widget<SearchGrid>(find.byType(SearchGrid));
    expect(grid.query, '');
    expect(grid.filters, expectedFilters);
  });

  testWidgets('a picker failure shows the existing photo error message', (tester) async {
    when(() => photos.pick()).thenThrow(StateError('picker failed'));
    await pumpScreen(tester);
    toasts.overlayResolver = () => tester.state<OverlayState>(find.byType(Overlay).first);

    await tester.tap(find.byTooltip(en.searchByPhoto));
    await settle(tester);

    expect(find.text(en.searchPhotoCouldNotOpen), findsOneWidget);
  });
}
