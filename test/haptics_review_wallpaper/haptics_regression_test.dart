import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_wallpaper_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/edit_wall_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/review_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/review_tile_parts.dart';
import 'package:bloc_test/bloc_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_firestore_client.dart';
import '../support/in_memory_local_store.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _SignedOutFirebaseAuthPlatform extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingUrlLauncher extends UrlLauncherPlatform {
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingDeleteFirestore extends FakeFirestoreClient {
  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) {
    final List<FirestoreDocument> docs = spec.collection == FirebaseCollections.walls
        ? <FirestoreDocument>[
            const FirestoreDocument('wall-1', <String, dynamic>{
              'wallpaper_thumb': '',
              'wallpaper_url': '',
              'size': '1 MB',
              'resolution': '100x200',
            }),
          ]
        : <FirestoreDocument>[];
    return Stream<List<T>>.value(docs.map((FirestoreDocument doc) => map(doc.data(), doc.id)).toList());
  }

  @override
  Future<void> deleteDoc(String collection, String id, {required String sourceTag}) {
    throw FirestoreError(code: 'permission-denied', message: 'denied');
  }
}

List<String> _recordHaptics(WidgetTester tester) {
  final List<String> events = <String>[];
  const MethodChannel channel = MethodChannel('prism/haptics');
  PrismHaptics.enabled = true;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'play') events.add(call.arguments! as String);
    return null;
  });
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    PrismHaptics.enabled = true;
  });
  return events;
}

Future<File> _createPng() async {
  final Directory directory = Directory.systemTemp.createTempSync('prism-haptics-test_');
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = Colors.red);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(8, 8);
  picture.dispose();
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  final File file = File('${directory.path}/wallpaper.png')..writeAsBytesSync(data.buffer.asUint8List());
  addTearDown(() => directory.deleteSync(recursive: true));
  return file;
}

Future<void> _waitForFilterReady(WidgetTester tester) async {
  for (int attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
    final Finder button = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
    if (tester.widget<IconButton>(button).onPressed != null) return;
  }
  fail('Wallpaper filter editor did not become ready');
}

void _registerDetailHarness(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  addTearDown(() => getIt.unregister<FavoritesLocalDataSource>());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TargetPlatformVariant android = TargetPlatformVariant.only(TargetPlatform.android);

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('edit sliders emit selection feedback once after drag updates finish', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final File image = (await tester.runAsync(_createPng))!;
    await tester.pumpWidget(MaterialApp(home: EditWallScreen(image: image)));

    final Slider slider = tester.widget<Slider>(find.byType(Slider).first);
    slider.onChanged!(0.4);
    slider.onChanged!(0.8);
    await tester.pump();
    expect(haptics, isEmpty);

    tester.widget<Slider>(find.byType(Slider).first).onChangeEnd!(0.8);
    await tester.pump();
    expect(haptics, <String>['selection']);
  }, variant: android);

  testWidgets('download wallpaper uses impact for long press and tap for tap', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    final File image = (await tester.runAsync(_createPng))!;
    await tester.pumpWidget(
      MaterialApp(
        home: DownloadWallpaperScreen(source: WallpaperSource.prism, file: image),
      ),
    );

    final Finder gestureFinder = find.byWidgetPredicate(
      (Widget widget) => widget is GestureDetector && widget.onTap != null && widget.onLongPress != null,
    );
    final GestureDetector gesture = tester.widget<GestureDetector>(gestureFinder.first);
    gesture.onTap!();
    gesture.onLongPress!();
    await tester.pump();

    expect(haptics, <String>['tap', 'impact']);
  }, variant: android);

  testWidgets('accent tap haptics only when cycling a valid palette', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    _registerDetailHarness(tester);
    const FeedItemEntity entity = FeedItemEntity.wallhaven(
      id: 'wall-1',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(
          id: 'wall-1',
          source: WallpaperSource.wallhaven,
          fullUrl: '',
          thumbnailUrl: '',
          authorName: 'artist',
        ),
      ),
    );
    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    addTearDown(bloc.close);

    Future<void> pumpDetail({required List<Color>? colors, required Color? accent}) async {
      final WallpaperDetailLoaded state = WallpaperDetailLoaded(
        entity: entity,
        paletteLoading: false,
        colors: colors,
        accent: accent,
      );
      whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: const WallpaperDetailScreen(wallId: 'wall-1', source: WallpaperSource.wallhaven),
          ),
        ),
      );
    }

    Future<void> tapWallpaper() async {
      final Finder gestureFinder = find.byWidgetPredicate(
        (Widget widget) => widget is GestureDetector && widget.onTap != null && widget.onLongPress != null,
      );
      tester.widget<GestureDetector>(gestureFinder.first).onTap!();
      await tester.pump();
    }

    await pumpDetail(colors: <Color>[Colors.red, Colors.blue], accent: Colors.red);
    await tapWallpaper();
    expect(haptics, <String>['selection']);
  }, variant: android);

  testWidgets('author launch failure emits an error haptic', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    _registerDetailHarness(tester);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final UrlLauncherPlatform previousLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FailingUrlLauncher();
    addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);

    const FeedItemEntity entity = FeedItemEntity.wallhaven(
      id: 'wall-1',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(
          id: 'wall-1',
          source: WallpaperSource.wallhaven,
          fullUrl: '',
          thumbnailUrl: '',
          authorName: 'artist',
        ),
      ),
    );
    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    addTearDown(bloc.close);
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: const WallpaperDetailLoaded(entity: entity, paletteLoading: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(wallId: 'wall-1', source: WallpaperSource.wallhaven),
        ),
      ),
    );
    final Finder authorLink = find.ancestor(of: find.text('artist'), matching: find.byType(InkWell)).first;
    tester.widget<InkWell>(authorLink).onTap!();
    await tester.pump();
    await tester.pump();

    expect(haptics, <String>['error']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: android);

  testWidgets('accent tap is silent while its palette is invalid', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    _registerDetailHarness(tester);
    const FeedItemEntity entity = FeedItemEntity.wallhaven(
      id: 'wall-1',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(id: 'wall-1', source: WallpaperSource.wallhaven, fullUrl: '', thumbnailUrl: ''),
      ),
    );
    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    addTearDown(bloc.close);
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: const WallpaperDetailLoaded(entity: entity, paletteLoading: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(wallId: 'wall-1', source: WallpaperSource.wallhaven),
        ),
      ),
    );

    final Finder gestureFinder = find.byWidgetPredicate(
      (Widget widget) => widget is GestureDetector && widget.onTap != null && widget.onLongPress != null,
    );
    tester.widget<GestureDetector>(gestureFinder.first).onTap!();
    await tester.pump();

    expect(haptics, isEmpty);
  }, variant: android);

  testWidgets('signed-out detail report only emits the error haptic', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    _registerDetailHarness(tester);
    final FirebaseAuthPlatform previousAuth = FirebaseAuthPlatform.instance;
    FirebaseAuthPlatform.instance = _SignedOutFirebaseAuthPlatform();
    addTearDown(() => FirebaseAuthPlatform.instance = previousAuth);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));

    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    addTearDown(bloc.close);
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: const WallpaperDetailLoaded(
        entity: FeedItemEntity.prism(
          id: 'wall-1',
          wallpaper: PrismWallpaper(
            core: WallpaperCore(id: 'wall-1', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
            firestoreDocumentId: 'wall-doc-1',
          ),
        ),
        paletteLoading: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(wallId: 'wall-1', source: WallpaperSource.prism),
        ),
      ),
    );
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Report')).onPressed!();
    await tester.pumpAndSettle();

    expect(haptics, <String>['error']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: android);

  testWidgets('review download start is quiet and failure emits an error haptic', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));

    const String saveChannel = 'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(saveChannel, (ByteData? message) async {
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: false)]);
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMessageHandler(saveChannel, null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReviewDownloadButton(
            link: 'https://example.test/wall.png',
            kind: SaveMediaKind.wallpaper,
            event: DownloadOwnWallEvent(link: 'https://example.test/wall.png'),
            successMessage: 'saved',
            failLogSuffix: 'test download',
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Download wallpaper'));
    await tester.pump();

    expect(haptics, <String>['error']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: android);

  testWidgets('review delete failure emits an error haptic', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    getIt.registerSingleton<FirestoreClient>(_FailingDeleteFirestore());
    addTearDown(() => getIt.unregister<FirestoreClient>());

    await tester.pumpWidget(const MaterialApp(home: ReviewScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete wallpaper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    expect(haptics, <String>['tap', 'error']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: android);

  testWidgets('filter processing toast does not duplicate the download tap haptic', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    const String saveChannel = 'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(saveChannel, (ByteData? message) async {
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: false)]);
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMessageHandler(saveChannel, null));
    app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final File image = (await tester.runAsync(_createPng))!;
    await tester.pumpWidget(MaterialApp(home: WallpaperFilterScreen(filePath: image.path)));
    await _waitForFilterReady(tester);
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();

    expect(haptics, <String>['tap', 'error']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: android);

  testWidgets('signed-out premium filter notice does not duplicate the tap haptic', (tester) async {
    final List<String> haptics = _recordHaptics(tester);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    app_state.prismUser = app_constants.createGuestPrismUser();
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final File image = (await tester.runAsync(_createPng))!;
    await tester.pumpWidget(MaterialApp(home: WallpaperFilterScreen(filePath: image.path)));
    await _waitForFilterReady(tester);
    await tester.tap(find.text('AddictiveBlue'));
    await tester.pump();
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();

    expect(haptics, <String>['selection', 'tap']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: android);
}
