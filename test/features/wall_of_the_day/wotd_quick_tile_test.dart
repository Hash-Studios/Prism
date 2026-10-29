import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wotd_quick_tile_listener.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/offline_asset_fixture.dart';
import '../../support/profile_user_fixture.dart';
import '../../support/wait_for_real_io.dart';

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

const WallOfTheDayEntity _wall = WallOfTheDayEntity(
  wallId: 'wall-1',
  url: 'https://example.com/wall-1.jpg',
  thumbnailUrl: 'https://example.com/wall-1-thumb.jpg',
  photographer: 'Ana',
  wallDocumentId: 'wall-document-1',
);

class _GatedAssetStore extends OfflineAssetStore {
  _GatedAssetStore(this.delegate) : super();

  final OfflineAssetStore delegate;
  final Completer<void> readStarted = Completer<void>();
  final Completer<void> releaseRead = Completer<void>();

  @override
  Future<Map<String, String>> localPaths() async {
    final Map<String, String> paths = await delegate.localPaths();
    if (!readStarted.isCompleted) readStarted.complete();
    await releaseRead.future;
    return paths;
  }
}

Widget _withWotdAndSession(WotdBloc wotdBloc, Widget child, {_MockSessionBloc? sessionBloc}) {
  final SessionBloc session = sessionBloc ?? _MockSessionBloc();
  if (sessionBloc == null) {
    whenListen(session as _MockSessionBloc, const Stream<SessionState>.empty(), initialState: SessionState.initial());
  }
  return MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<WotdBloc>.value(value: wotdBloc),
      BlocProvider<SessionBloc>.value(value: session),
    ],
    child: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OfflineAssetFixture fixture;

  setUp(() async {
    fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
    fixture.install();
  });

  tearDown(() => fixture.dispose());

  Future<void> verifySessionClearFailureRecovery(WidgetTester tester) async {
    // Exercise the default channel store before setMockInitialValues installs its in-memory store.
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    for (final failedMethod in <String>['setString', 'remove']) {
      final persisted = <String, Object>{'flutter.${PersistenceKeys.quickTileWotdTarget}': 'both'};
      final calls = <MethodCall>[];
      var failClear = false;
      var failed = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getAll') return Map<String, Object>.of(persisted);
        final arguments = call.arguments as Map<Object?, Object?>;
        final key = arguments['key']! as String;
        if (failClear &&
            call.method == failedMethod &&
            key ==
                (failedMethod == 'setString'
                    ? 'flutter.${NativeAssetPathsStore.preferenceKey}.wotd'
                    : 'flutter.${QuickTileConfigService.wotdRetainedKey}')) {
          failed = true;
          return false;
        }
        if (call.method == 'remove') {
          persisted.remove(key);
        } else {
          persisted[key] = arguments['value']!;
        }
        return true;
      });
      SharedPreferences.resetStatic();
      final bloc = _MockWotdBloc();
      whenListen(
        bloc,
        const Stream<WotdState>.empty(),
        initialState: WotdState.initial().copyWith(status: LoadStatus.success, entity: _wall),
      );
      final session = _MockSessionBloc();
      final states = StreamController<SessionState>();
      SessionState signedIn(String userId) => SessionState.initial().copyWith(
        session: SessionEntity(userId: userId, loggedIn: true, premium: false, subscriptionTier: 'free'),
      );
      whenListen(session, states.stream, initialState: signedIn('alice'));
      await tester.pumpWidget(
        _withWotdAndSession(bloc, const WotdQuickTileListener(child: SizedBox.shrink()), sessionBloc: session),
      );
      await waitForRealIo(
        tester,
        () => persisted['flutter.${PersistenceKeys.quickTileWotdUrl}'] == _wall.url,
        reason: 'initial mirror before failed $failedMethod',
      );
      InMemoryLogSink.instance.clear();
      calls.clear();
      failClear = true;
      states.add(signedIn('bob'));
      await waitForRealIo(tester, () => failed, reason: 'injected session $failedMethod failure');
      var drained = false;
      NativeAssetPathsStore.replaceGroup('category', const <String, String>{}).then((_) => drained = true);
      await waitForRealIo(tester, () => drained, reason: 'queue after failed session clear');
      expect(tester.takeException(), isNull);
      expect(
        InMemoryLogSink.instance.records.where((entry) => entry.message.contains('Could not update Wall')),
        hasLength(1),
      );
      expect(
        calls.where(
          (call) => call.method == 'setString' && (call.arguments as Map<Object?, Object?>)['value'] == _wall.url,
        ),
        isEmpty,
        reason: 'a failed clear must not remirror the current WOTD',
      );
      failClear = false;
      calls.clear();
      states.add(signedIn('carol'));
      await waitForRealIo(
        tester,
        () => calls.any(
          (call) => call.method == 'setString' && (call.arguments as Map<Object?, Object?>)['value'] == _wall.url,
        ),
        reason: 'later session remirror recovers after $failedMethod failure',
      );
      expect(tester.takeException(), isNull);
      expect(
        InMemoryLogSink.instance.records.where((entry) => entry.message.contains('Could not update Wall')),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await states.close();
      drained = false;
      NativeAssetPathsStore.replaceGroup('category', const <String, String>{}).then((_) => drained = true);
      await waitForRealIo(tester, () => drained, reason: 'recovered session mirror drained');
    }
    messenger.setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
  }

  Future<void> verifyAndroidProtectedHandoff(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersistenceKeys.quickTileWotdTarget: 'both',
      PersistenceKeys.quickTileWotdUrl: 'https://example.com/old.jpg',
    });
    app_state.prismUser = profileUser(id: 'alice');
    addTearDown(() => app_state.prismUser = profileUser(id: '', loggedIn: false));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final index = DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore()), ownerId: () => 'alice');
    getIt.registerSingleton<DownloadedWallIndex>(index);
    // Reset before the handoff test registers its own index.
    final day = DateTime.utc(2026, 8, 24);
    final wall = WallOfTheDayEntity(
      wallId: 'logical-id',
      url: '',
      thumbnailUrl: 'preview',
      photographer: 'Ana',
      wallDocumentId: 'protected-doc',
      featuredDayUtc: day,
    );
    final bloc = _MockWotdBloc();
    whenListen(
      bloc,
      const Stream<WotdState>.empty(),
      initialState: WotdState.initial().copyWith(status: LoadStatus.success, entity: wall),
    );
    final session = _MockSessionBloc();
    final states = StreamController<SessionState>();
    whenListen(
      session,
      states.stream,
      initialState: SessionState.initial().copyWith(
        session: const SessionEntity(userId: 'alice', loggedIn: true, premium: false, subscriptionTier: 'free'),
      ),
    );
    final file = File('${fixture.directory.path}/PrismDownloads/acquired.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync((await fixture.createImage('original.png')).readAsBytesSync());
    var listed = <String>[];
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[DownloadItemsResult(success: true, items: listed)],
    );
    addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));
    await tester.pumpWidget(
      _withWotdAndSession(bloc, const WotdQuickTileListener(child: SizedBox.shrink()), sessionBloc: session),
    );
    final prefs = await SharedPreferences.getInstance();
    await waitForRealIo(
      tester,
      () => prefs.getString('quick_tile.wotd.url') == '',
      reason: 'protected WOTD quick-tile URL persistence',
    );
    listed = [file.path];
    await index.remember(link: 'https://expired.example/acquired.png', id: 'logical-id', source: WallpaperSource.prism);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await waitForRealIo(
      tester,
      () => prefs.getString('quick_tile.wotd.retained') != null,
      reason: 'protected original acquisition handoff mirror',
    );
    expect(jsonDecode(prefs.getString('offline.native_asset_paths')!), <String, String>{
      'wotd:protected-doc': file.path,
    });
    expect(jsonDecode(prefs.getString('quick_tile.wotd.retained')!)['assetKey'], 'wotd:protected-doc');
    expect(prefs.getString('quick_tile.wotd.url'), '');
    await tester.pumpWidget(const SizedBox.shrink());
    await states.close();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    var drained = false;
    NativeAssetPathsStore.replaceGroup('category', const <String, String>{}).then((_) => drained = true);
    await waitForRealIo(tester, () => drained, reason: 'protected handoff mirror drained');
    debugDefaultTargetPlatformOverride = null;
    await getIt.reset();
  }

  Future<void> verifyOriginalAcquisitionHandoff(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersistenceKeys.quickTileWotdTarget: 'both',
      PersistenceKeys.quickTileWotdUrl: 'https://example.com/old.jpg',
    });
    app_state.prismUser = profileUser(id: 'alice');
    addTearDown(() => app_state.prismUser = profileUser(id: '', loggedIn: false));
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final index = DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore()), ownerId: () => 'alice');
    getIt.registerSingleton<DownloadedWallIndex>(index);
    addTearDown(() => getIt.reset());
    final day = DateTime.utc(2026, 8, 24);
    final wall = WallOfTheDayEntity(
      wallId: 'logical-id',
      url: '',
      thumbnailUrl: 'preview',
      photographer: 'Ana',
      wallDocumentId: 'actual-document',
      featuredDayUtc: day,
    );
    final bloc = _MockWotdBloc();
    whenListen(
      bloc,
      const Stream<WotdState>.empty(),
      initialState: WotdState.initial().copyWith(status: LoadStatus.success, entity: wall),
    );
    final session = _MockSessionBloc();
    final states = StreamController<SessionState>();
    whenListen(
      session,
      states.stream,
      initialState: SessionState.initial().copyWith(
        session: const SessionEntity(userId: 'alice', loggedIn: true, premium: false, subscriptionTier: 'free'),
      ),
    );
    final file = File('${fixture.directory.path}/PrismDownloads/acquired.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync((await fixture.createImage('original.png')).readAsBytesSync());
    var listed = <String>[];
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[DownloadItemsResult(success: true, items: listed)],
    );
    addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));
    await tester.pumpWidget(
      _withWotdAndSession(bloc, const WotdQuickTileListener(child: SizedBox.shrink()), sessionBloc: session),
    );
    final prefs = await SharedPreferences.getInstance();
    await waitForRealIo(
      tester,
      () => prefs.getString(PersistenceKeys.quickTileWotdUrl) == '',
      reason: 'unacquired pick',
    );
    expect(prefs.getString(QuickTileConfigService.wotdRetainedKey), isNull);
    listed = [file.path];
    // This is the real acquisition-index write performed after native download success, not a new WOTD emission.
    await index.remember(link: 'https://expired.example/acquired.png', id: 'logical-id', source: WallpaperSource.prism);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await waitForRealIo(
      tester,
      () => prefs.getString(QuickTileConfigService.wotdRetainedKey) != null,
      reason: 'original acquisition handoff mirror',
    );
    expect(jsonDecode(prefs.getString(QuickTileConfigService.wotdRetainedKey)!), <String, String>{
      'documentId': 'actual-document',
      'featuredDayUtc': day.toIso8601String(),
      'assetKey': 'wotd:actual-document',
    });
    expect(jsonDecode(prefs.getString(NativeAssetPathsStore.preferenceKey)!), <String, String>{
      'wotd:actual-document': 'acquired.png',
    });
    states.add(SessionState.initial());
    await tester.pump();
    await waitForRealIo(
      tester,
      () => prefs.getString(QuickTileConfigService.wotdRetainedKey) == null,
      reason: 'sign-out clears retained metadata',
    );
    expect(prefs.getString('${NativeAssetPathsStore.preferenceKey}.wotd'), '{}');
    await tester.pumpWidget(const SizedBox.shrink());
    await states.close();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    var drained = false;
    NativeAssetPathsStore.replaceGroup('category', const <String, String>{}).then((_) => drained = true);
    await waitForRealIo(tester, () => drained, reason: 'handoff mirror drained');
    debugDefaultTargetPlatformOverride = null;
  }

  Future<void> verifyPendingLookupDisposal(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersistenceKeys.quickTileWotdTarget: 'both',
      PersistenceKeys.quickTileWotdUrl: 'https://example.com/old.jpg',
    });
    InMemoryLogSink.instance.clear();
    final gated = _GatedAssetStore(OfflineAssetStore.instance);
    OfflineAssetStore.testOverride = gated;
    final bloc = _MockWotdBloc();
    whenListen(
      bloc,
      const Stream<WotdState>.empty(),
      initialState: WotdState.initial().copyWith(status: LoadStatus.success, entity: _wall),
    );
    await tester.pumpWidget(_withWotdAndSession(bloc, const WotdQuickTileListener(child: SizedBox.shrink())));
    await waitForRealIo(tester, () => gated.readStarted.isCompleted, reason: 'pending retained lookup');
    await tester.pumpWidget(const SizedBox.shrink());
    gated.releaseRead.complete();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    expect(tester.takeException(), isNull);
    expect(InMemoryLogSink.instance.records.where((entry) => entry.message.contains('Could not update Wall')), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PersistenceKeys.quickTileWotdUrl), 'https://example.com/old.jpg');
    OfflineAssetStore.testOverride = gated.delegate;
  }

  testWidgets('WOTD mirror follows state, disposal, original acquisition handoff and logout', (tester) async {
    await verifySessionClearFailureRecovery(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersistenceKeys.quickTileWotdTarget: 'both',
      PersistenceKeys.quickTileWotdUrl: 'https://example.com/old.jpg',
    });
    {
      final OfflineAssetStore delegate = OfflineAssetStore.instance;
      final _GatedAssetStore gatedStore = _GatedAssetStore(delegate);
      OfflineAssetStore.testOverride = gatedStore;
      final _MockWotdBloc bloc = _MockWotdBloc();
      final StreamController<WotdState> states = StreamController<WotdState>();
      whenListen(bloc, states.stream, initialState: WotdState.initial().copyWith(status: LoadStatus.loading));
      await tester.pumpWidget(_withWotdAndSession(bloc, const WotdQuickTileListener(child: SizedBox.shrink())));
      states.add(WotdState.initial().copyWith(status: LoadStatus.success, entity: _wall));
      await tester.pump();
      await waitForRealIo(tester, () => gatedStore.readStarted.isCompleted, reason: 'initial WOTD asset read');
      states.add(WotdState.initial().copyWith(status: LoadStatus.loading, entity: _wall));
      await tester.pump();
      states.add(WotdState.initial().copyWith(status: LoadStatus.failure, entity: _wall));
      await tester.pump();
      expect(bloc.state.status, LoadStatus.failure);
      gatedStore.releaseRead.complete();
      await tester.pump();
      var mirrorDrained = false;
      NativeAssetPathsStore.replaceGroup('category', const <String, String>{}).then((_) => mirrorDrained = true);
      await waitForRealIo(tester, () => mirrorDrained, reason: 'native mirror queue after stale WOTD read');
      await tester.pump();
      expect((await QuickTileConfigService.loadWotdTileConfig())?.cachedUrl, 'https://example.com/old.jpg');
      await tester.pumpWidget(const SizedBox.shrink());
      await states.close();
      OfflineAssetStore.testOverride = delegate;
    }
    {
      final _MockWotdBloc bloc = _MockWotdBloc();
      final StreamController<WotdState> states = StreamController<WotdState>();
      whenListen(bloc, states.stream, initialState: WotdState.initial().copyWith(status: LoadStatus.loading));

      await tester.pumpWidget(_withWotdAndSession(bloc, const WotdQuickTileListener(child: SizedBox.shrink())));
      states.add(WotdState.initial().copyWith(status: LoadStatus.success));
      await tester.pump();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await waitForRealIo(
        tester,
        () => prefs.getString(PersistenceKeys.quickTileWotdUrl) == '',
        reason: 'empty WOTD quick-tile URL persistence',
      );
      final String? cachedUrl = (await QuickTileConfigService.loadWotdTileConfig())?.cachedUrl;
      await tester.pumpWidget(const SizedBox.shrink());
      await states.close();
      expect(cachedUrl, '');
    }

    {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.quickTileWotdTarget: 'both',
        PersistenceKeys.quickTileWotdUrl: 'https://example.com/old.jpg',
      });
      final _MockWotdBloc bloc = _MockWotdBloc();
      final StreamController<WotdState> states = StreamController<WotdState>();
      whenListen(bloc, states.stream, initialState: WotdState.initial().copyWith(status: LoadStatus.loading));

      await tester.pumpWidget(_withWotdAndSession(bloc, const WotdQuickTileListener(child: SizedBox.shrink())));
      states.add(WotdState.initial().copyWith(status: LoadStatus.success, entity: _wall));
      await tester.pump();
      expect(bloc.state.entity?.url, _wall.url);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await waitForRealIo(
        tester,
        () => prefs.getString(PersistenceKeys.quickTileWotdUrl) == 'https://example.com/wall-1.jpg',
        reason: 'successful WOTD quick-tile URL persistence',
      );
      File? retained;
      OfflineAssetStore.instance
          .retain(_wall.url, file: fixture.createImageSync('android-wotd.png'))
          .then((file) => retained = file);
      await waitForRealIo(tester, () => retained != null, reason: 'retained Android WOTD bytes');
      final String retainedPath = retained!.path;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await waitForRealIo(
        tester,
        () => prefs.getString(NativeAssetPathsStore.preferenceKey)?.contains(retainedPath) == true,
        reason: 'Android retained WOTD path mirror with a document ID',
      );
      final String nativeUrl = prefs.getString(PersistenceKeys.quickTileWotdUrl)!.trim();
      final nativePaths = jsonDecode(prefs.getString(NativeAssetPathsStore.preferenceKey)!) as Map<String, dynamic>;
      expect(nativePaths[nativeUrl], retainedPath);
      expect(nativePaths, <String, String>{nativeUrl: retainedPath});
      final String? cachedUrl = (await QuickTileConfigService.loadWotdTileConfig())?.cachedUrl;
      await tester.pumpWidget(const SizedBox.shrink());
      await states.close();
      expect(cachedUrl, 'https://example.com/wall-1.jpg');
    }

    {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.quickTileWotdTarget: 'both',
        PersistenceKeys.quickTileWotdUrl: 'https://example.com/wall-1.jpg',
        'offline.native_asset_paths.wotd': '{"https://example.com/wall-1.jpg":"assets/wall.jpg"}',
        'offline.native_asset_paths': '{"https://example.com/wall-1.jpg":"assets/wall.jpg"}',
      });
      final _MockWotdBloc wotdBloc = _MockWotdBloc();
      final StreamController<WotdState> wotdStates = StreamController<WotdState>();
      whenListen(wotdBloc, wotdStates.stream, initialState: WotdState.initial().copyWith(status: LoadStatus.loading));
      final _MockSessionBloc sessionBloc = _MockSessionBloc();
      final StreamController<SessionState> sessionStates = StreamController<SessionState>();
      whenListen(
        sessionBloc,
        sessionStates.stream,
        initialState: SessionState.initial().copyWith(
          status: LoadStatus.success,
          session: const SessionEntity(userId: 'same-user', loggedIn: true, premium: false, subscriptionTier: 'free'),
        ),
      );

      await tester.pumpWidget(
        _withWotdAndSession(wotdBloc, const WotdQuickTileListener(child: SizedBox.shrink()), sessionBloc: sessionBloc),
      );
      sessionStates.add(
        SessionState.initial().copyWith(
          status: LoadStatus.success,
          session: const SessionEntity(userId: 'same-user', loggedIn: false, premium: false, subscriptionTier: 'free'),
        ),
      );
      await tester.pump();
      await tester.pump();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await waitForRealIo(
        tester,
        () => prefs.getString('offline.native_asset_paths.wotd') == '{}',
        reason: 'logout clears the WOTD native path mirror',
      );
      expect(prefs.getString('offline.native_asset_paths.wotd'), '{}');
      await tester.pumpWidget(const SizedBox.shrink());
      await wotdStates.close();
      await sessionStates.close();
    }
    await verifyPendingLookupDisposal(tester);
    await verifyAndroidProtectedHandoff(tester);
    await verifyOriginalAcquisitionHandoff(tester);
  });
}
