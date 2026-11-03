import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/wallpaper_image_finders.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

class _ThrowingPicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) => Future<XFile?>.error(PlatformException(code: 'photo_access_denied'));
}

const Size _device = Size(390, 844);

PrismWallpaper _variant(int index, String colour) => PrismWallpaper(
  core: WallpaperCore(
    id: 'v$index',
    source: WallpaperSource.prism,
    fullUrl: 'https://example.com/v$index-full.jpg',
    thumbnailUrl: 'https://example.com/v$index-thumb.jpg',
    authorUid: 'creator-uid',
  ),
  review: true,
  firestoreDocumentId: 'doc$index',
  colors: [colour],
  variantGroupId: 'doc0',
  variantIndex: index,
);

final PrismWallpaper _v0 = _variant(0, 'blue');
final PrismWallpaper _v1 = _variant(1, 'red');
final PrismWallpaper _v2 = _variant(2, 'green');
final VariantGroup _group = VariantGroup(id: 'doc0', walls: [_v0, _v1, _v2]);

FeedItemEntity _entity(PrismWallpaper wall) => FeedItemEntity.prism(id: wall.id, wallpaper: wall);

FeedItemEntity _plain(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
    ),
  ),
);

WallpaperDetailLoaded _state({required FeedItemEntity entity, VariantGroup? variants}) => WallpaperDetailLoaded(
  entity: entity,
  variants: variants,
  paletteLoading: false,
  panelCollapsed: false,
  recommendations: const RecommendationState.exhausted(),
);

WallpaperFeed _feedOf(BuildContext context, List<FeedItemEntity> items) => WallpaperFeed(
  grid: context,
  tiles: [for (final (i, item) in items.indexed) (item: item, index: i, heroTag: 'tile-$i')],
);

Finder _keyed(String key) => find.byWidgetPredicate((Widget w) => w is KeyedSubtree && w.key == ValueKey<String>(key));

Finder get _card => find.byType(WallpaperQuickActionRegion).first;

bool _controlsShown(WidgetTester tester) => find.byTooltip('Back').hitTestable().evaluate().isNotEmpty;

void main() {
  setUpFavouriteCounts();
  setUpAll(() {
    registerFallbackValue(const SelectVariant(index: 0));
  });

  late OfflineAssetFixture offlineAssets;
  late List<String> warmed;
  late Future<void> Function(BuildContext, WallpaperDisplaySource) originalPrecache;
  final List<WallpaperDetailState> blocStates = <WallpaperDetailState>[];
  final List<_MockWallpaperDetailBloc> createdBlocs = <_MockWallpaperDetailBloc>[];

  setUp(() async {
    warmed = <String>[];
    blocStates.clear();
    createdBlocs.clear();
    originalPrecache = WallpaperDetailScreen.precacheVariant;
    WallpaperDetailScreen.precacheVariant = (context, WallpaperDisplaySource display) async {
      warmed.add(display.thumbnail);
    };
    AnalyticsRuntime.reset();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    // Most cases are not about the first-run immersive hint.
    await settings.set('wallpaper_detail.immersive_hint_shown', true);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    getIt.registerSingleton<DownloadedWallIndex>(DownloadedWallIndex(settings));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
      createdBlocs.add(bloc);
      whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: blocStates.removeAt(0));
      return bloc;
    });
  });

  tearDown(() async {
    WallpaperDetailScreen.precacheVariant = originalPrecache;
    await offlineAssets.dispose();
    await getIt.reset();
  });

  /// Pumps the screen for [state] with its own bloc. [opened] is the wall the screen was opened with, when not the
  /// wall on screen.
  Future<_MockWallpaperDetailBloc> pumpDetail(
    WidgetTester tester,
    WallpaperDetailLoaded state, {
    FeedItemEntity? opened,
    File? localFile,
    bool disableAnimations = false,
    TextScaler? textScaler,
    Stream<WallpaperDetailState>? states,
  }) async {
    tester.view.physicalSize = _device;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, states ?? const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations, textScaler: textScaler),
          child: child!,
        ),
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: opened ?? state.entity, localFile: localFile),
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  /// Pumps a feed of [feed] with the detail of [open] on top. Each detail page takes its state from [states] in the
  /// order the pages are created.
  Future<void> pumpFeed(
    WidgetTester tester, {
    required List<FeedItemEntity> feed,
    required FeedItemEntity open,
    required List<WallpaperDetailState> states,
  }) async {
    tester.view.physicalSize = _device;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    blocStates.addAll(states);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => WallpaperDetailScreen(
            entity: open,
            feed: _feedOf(context, feed),
            heroTag: 'tile-${feed.indexOf(open)}',
          ).wrappedRoute(context),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows one dot per variant with its label', (tester) async {
    await pumpDetail(tester, _state(entity: _entity(_v0), variants: _group));

    expect(find.bySemanticsLabel(RegExp(r'^Variant \d of 3')), findsNWidgets(3));
    expect(find.bySemanticsLabel('Variant 1 of 3, Blue'), findsOneWidget);
    expect(find.bySemanticsLabel('Variant 2 of 3, Red'), findsOneWidget);
    expect(find.bySemanticsLabel('Variant 3 of 3, Green'), findsOneWidget);
    expect(find.text('3 colours'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Variant 1 of 3, Blue')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Variant 2 of 3, Red')),
      isSemantics(isButton: true, isSelected: false),
    );
  });

  testWidgets('each dot has a 44 point target', (tester) async {
    await pumpDetail(tester, _state(entity: _entity(_v0), variants: _group));

    for (final String label in <String>['Variant 1 of 3, Blue', 'Variant 2 of 3, Red', 'Variant 3 of 3, Green']) {
      final Size size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('a tap on a dot selects that variant', (tester) async {
    final _MockWallpaperDetailBloc bloc = await pumpDetail(tester, _state(entity: _entity(_v0), variants: _group));

    await tester.tap(find.bySemanticsLabel('Variant 3 of 3, Green'));
    await tester.pump();

    verify(() => bloc.add(const SelectVariant(index: 2))).called(1);
  });

  testWidgets('a tap on the wall selects the next variant', (tester) async {
    final _MockWallpaperDetailBloc bloc = await pumpDetail(tester, _state(entity: _entity(_v0), variants: _group));

    await tester.tapAt(tester.getCenter(find.byType(ProgressiveWallpaperImage).first));
    await tester.pump();

    verify(() => bloc.add(const SelectVariant(index: 1))).called(1);
  });

  testWidgets('a wall with no variants keeps the immersive tap', (tester) async {
    final FeedItemEntity solo = _plain('solo');
    await pumpFeed(
      tester,
      feed: [solo],
      open: solo,
      states: [_state(entity: solo)],
    );
    expect(_controlsShown(tester), isTrue);

    await tester.tapAt(tester.getCenter(_card));
    await tester.pumpAndSettle();

    verifyNever(() => createdBlocs.first.add(any(that: isA<SelectVariant>())));
    expect(_controlsShown(tester), isFalse);
  });

  testWidgets('Download and Set use the selected variant', (tester) async {
    await pumpDetail(tester, _state(entity: _entity(_v1), variants: _group));

    final SetWallpaperButton set = tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton));
    expect(set.wallpaperId, _v1.id);
    expect(set.url, _v1.core.fullUrl);
    final DownloadButton download = tester.widget<DownloadButton>(find.byType(DownloadButton));
    expect(download.contentId, _v1.id);
    expect(download.link, _v1.core.fullUrl);
  });

  testWidgets('Download and Set ignore the opened local file for another variant', (tester) async {
    final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>.broadcast();
    addTearDown(states.close);
    await pumpDetail(
      tester,
      _state(entity: _entity(_v0), variants: _group),
      opened: _entity(_v0),
      localFile: File('/tmp/v0.jpg'),
      states: states.stream,
    );
    expect(tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).url, '/tmp/v0.jpg');

    states.add(_state(entity: _entity(_v1), variants: _group));
    await tester.pump();
    await tester.pump();

    final SetWallpaperButton set = tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton));
    expect(set.wallpaperId, _v1.id);
    expect(set.url, _v1.core.fullUrl);
    expect(set.url, isNot('/tmp/v0.jpg'));
    final DownloadButton download = tester.widget<DownloadButton>(find.byType(DownloadButton));
    expect(download.contentId, _v1.id);
    expect(download.link, _v1.core.fullUrl);
    expect(download.link, isNot('/tmp/v0.jpg'));
  });

  testWidgets('an incoming variant does not inherit the outgoing variant tint during its cross-fade', (tester) async {
    final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>.broadcast();
    addTearDown(states.close);
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        entity: _entity(_v0),
        variants: _group,
        paletteLoading: false,
        accent: const Color(0xff0000ff),
        colorChanged: true,
        recommendations: const RecommendationState.exhausted(),
      ),
      states: states.stream,
    );

    states.add(_state(entity: _entity(_v1), variants: _group));
    await tester.pump();

    expect(find.ancestor(of: _keyed('prism:v1'), matching: find.byType(ColorFiltered)), findsNothing);
    expect(find.descendant(of: _keyed('prism:v0'), matching: find.byType(ColorFiltered)), findsOneWidget);
  });

  testWidgets('warms every variant once', (tester) async {
    final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>.broadcast();
    addTearDown(states.close);
    await pumpDetail(tester, _state(entity: _entity(_v0)), states: states.stream);
    expect(warmed, isEmpty);

    // The listener warms on a change of state, so the group arrives as a new state.
    states.add(_state(entity: _entity(_v0), variants: _group));
    await tester.pump();
    expect(warmed, [
      'https://example.com/v0-thumb.jpg',
      'https://example.com/v1-thumb.jpg',
      'https://example.com/v2-thumb.jpg',
    ]);

    // The same group on another wall must not warm the set again.
    states.add(_state(entity: _entity(_v1), variants: _group));
    await tester.pump();
    expect(warmed, hasLength(3));
  });

  for (final bool reduce in <bool>[true, false]) {
    testWidgets(
      reduce ? 'reduced motion switches with no cross-fade' : 'a variant change cross-fades before it settles',
      (tester) async {
        final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>.broadcast();
        addTearDown(states.close);
        await pumpDetail(
          tester,
          _state(entity: _entity(_v0), variants: _group),
          disableAnimations: reduce,
          states: states.stream,
        );
        states.add(_state(entity: _entity(_v1), variants: _group));
        await tester.pump();

        if (reduce) {
          expect(_keyed('prism:v1'), findsOneWidget);
          expect(_keyed('prism:v0'), findsNothing);
          return;
        }
        await tester.pump(const Duration(milliseconds: 50));
        expect(_keyed('prism:v0'), findsOneWidget);
        expect(_keyed('prism:v1'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        expect(_keyed('prism:v1'), findsOneWidget);
        expect(_keyed('prism:v0'), findsNothing);
      },
    );
  }

  testWidgets('large text keeps the dots usable', (tester) async {
    await pumpDetail(
      tester,
      _state(entity: _entity(_v0), variants: _group),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    for (final String label in <String>['Variant 1 of 3, Blue', 'Variant 2 of 3, Red', 'Variant 3 of 3, Green']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      final Size size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('feed swipe moves wall to wall, not variant to variant', (tester) async {
    final FeedItemEntity b = _plain('b');
    await pumpFeed(
      tester,
      feed: [_entity(_v0), b],
      open: _entity(_v0),
      states: [
        _state(entity: _entity(_v0), variants: _group),
        _state(entity: b),
      ],
    );

    List<String?> urls() => networkImageUrls(tester).toList();
    expect(urls(), contains('https://example.com/v0-thumb.jpg'));
    expect(find.byType(Hero), findsOneWidget);

    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(urls(), contains('https://example.com/b-thumb.jpg'));
    expect(urls().where((u) => u!.contains('v0')), isEmpty);
    expect(tester.widget<Hero>(find.byType(Hero)).tag, 'tile-1');
    verifyNever(() => createdBlocs.first.add(any(that: isA<SelectVariant>())));
  });

  testWidgets('immersive on a variant wall, a tap shows the controls and keeps the variant', (tester) async {
    const String immersive = 'SystemUiMode.immersiveSticky';
    const String edgeToEdge = 'SystemUiMode.edgeToEdge';
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<String> modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') modes.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpFeed(
      tester,
      feed: [_entity(_v0)],
      open: _entity(_v0),
      states: [_state(entity: _entity(_v0), variants: _group)],
    );
    expect(_controlsShown(tester), isTrue);

    final SemanticsFinder wall = find.semantics.byLabel(RegExp(r'^Wallpaper$'));
    tester.semantics.customAction(wall, const CustomSemanticsAction(label: 'Hide controls'));
    await tester.pumpAndSettle();
    expect(_controlsShown(tester), isFalse);
    expect(modes.last, immersive);

    await tester.tapAt(tester.getCenter(_card));
    await tester.pumpAndSettle();
    expect(_controlsShown(tester), isTrue);
    expect(modes.last, edgeToEdge);
    verifyNever(() => createdBlocs.first.add(any(that: isA<SelectVariant>())));

    await tester.tapAt(tester.getCenter(_card));
    await tester.pumpAndSettle();
    verify(() => createdBlocs.first.add(const SelectVariant(index: 1))).called(1);
    expect(_controlsShown(tester), isTrue);

    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('a picker failure shows an error and opens no upload', (tester) async {
    final ImagePickerPlatform previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _ThrowingPicker();
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);
    final PrismUsersV2 previousUser = app_state.prismUser;
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'owner-uid'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = previousUser);
    final List<MethodCall> toastCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (
      call,
    ) async {
      if (call.method == 'showToast') toastCalls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      ),
    );
    final PrismWallpaper owned = PrismWallpaper(
      core: WallpaperCore(
        id: 'v0',
        source: WallpaperSource.prism,
        fullUrl: 'https://example.com/v0-full.jpg',
        thumbnailUrl: 'https://example.com/v0-thumb.jpg',
        authorUid: 'owner-uid',
      ),
      review: true,
      firestoreDocumentId: 'doc0',
      colors: const ['blue'],
      variantGroupId: 'doc0',
      variantIndex: 0,
    );
    final VariantGroup group = VariantGroup(id: 'doc0', walls: [owned, _v1, _v2]);
    registerFallbackValue(UploadWallRoute(image: File('unused.jpg')));
    final _MockStackRouter router = _MockStackRouter();
    tester.view.physicalSize = _device;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: _state(entity: _entity(owned), variants: group),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(entity: _entity(owned)),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.text('Add a colour variant'));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    verifyNever(() => router.push(any(that: isA<UploadWallRoute>())));
    expect(toastCalls.map((call) => call.arguments['msg']), contains('Something went wrong. Try again.'));
  });
}
