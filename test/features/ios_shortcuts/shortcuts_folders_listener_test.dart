import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_folders_store.dart';
import 'package:Prism/features/ios_shortcuts/views/widgets/shortcuts_folders_listener.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/session.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../support/profile_user_fixture.dart';
import '../../support/wait_for_real_io.dart';

class _FoldersBloc extends MockBloc<FoldersEvent, FoldersState> implements FoldersBloc {}

class _SessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

class _RecordingStore extends InMemorySharedPreferencesStore {
  _RecordingStore(super.data) : super.withData();

  final List<Object> writes = <Object>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final bool saved = await super.setValue(valueType, key, value);
    if (key == 'flutter.${PersistenceKeys.shortcutsFolders}') writes.add(value);
    return saved;
  }
}

class _EmptyOfflineAssetStore extends OfflineAssetStore {
  @override
  Future<Map<String, String>> localPaths() async => <String, String>{};
}

class _FakeFoldersRepository implements FoldersRepository {
  final Map<String, List<FavouriteWallEntity>?> walls = <String, List<FavouriteWallEntity>?>{};
  final List<String> fetched = <String>[];

  @override
  int get writeRevision => 0;

  @override
  Stream<FolderWriteFailure> get writeFailures => const Stream<FolderWriteFailure>.empty();

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) => throw UnimplementedError();

  @override
  Future<Result<List<FavouriteWallEntity>?>> fetchItems(String folderId, {required String userId, int? limit}) async {
    fetched.add(folderId);
    return Result.success<List<FavouriteWallEntity>?>(walls[folderId]);
  }

  @override
  Future<Result<Set<String>>> foldersContaining(List<String> folderIds, String itemKey) => throw UnimplementedError();

  @override
  Future<Result<void>> createFolder(FolderEntity folder, {FavouriteWallEntity? firstWall}) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> renameFolder(FolderEntity folder) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteFolder(String folderId, {required String userId, bool Function()? isCancelled}) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall) => throw UnimplementedError();

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall) => throw UnimplementedError();
}

FavouriteWallEntity _wall(String id) => LegacyFavouriteWall(
  id: id,
  source: WallpaperSource.prism,
  legacyPayload: <String, dynamic>{'url': 'https://example.com/$id.jpg'},
);

FolderEntity _folder(String id, {String owner = 'u1', DateTime? updatedAt}) => FolderEntity(
  id: id,
  ownerId: owner,
  name: 'Folder $id',
  createdAt: DateTime.utc(2026),
  updatedAt: updatedAt ?? DateTime.utc(2026, 2),
  itemCount: 1,
  covers: const <String>[],
);

FoldersState _folders(String userId, List<FolderEntity> folders) =>
    FoldersState.initial().copyWith(status: LoadStatus.success, userId: userId, folders: folders);

SessionState _resolvedGuest() => SessionState.initial().copyWith(status: LoadStatus.success);

SessionState _session(String userId) => SessionState.initial().copyWith(
  status: LoadStatus.success,
  session: SessionEntity(userId: userId, loggedIn: true, premium: false, subscriptionTier: 'free'),
);

Future<void> _settle(
  WidgetTester tester,
  bool Function() isReady, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  await tester.runAsync(() => Future<void>(() {}));
  await tester.pump();
  await waitForRealIo(tester, isReady, reason: reason, timeout: timeout);
  await tester.runAsync(() => Future<void>(() {}));
  await tester.pump();
}

Future<String?> _stored() async => (await SharedPreferences.getInstance()).getString(PersistenceKeys.shortcutsFolders);

Future<void> _installStore(WidgetTester tester, SharedPreferencesStorePlatform store) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
  });
  await tester.runAsync(() async {
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    await SharedPreferences.getInstance();
  });
}

Future<void> _finish(
  WidgetTester tester,
  StreamController<FoldersState> folders,
  StreamController<SessionState> session, {
  bool drainWrites = true,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await folders.close();
  await session.close();
  if (drainWrites) {
    bool cleared = false;
    ShortcutsFoldersStore.clear().then((_) => cleared = true);
    await _settle(tester, () => cleared, reason: 'drain folder writes before leaving the fake async zone');
  }
}

Map<String, dynamic> _decode(String json) => jsonDecode(json) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    OfflineAssetStore.testOverride = _EmptyOfflineAssetStore();
  });

  tearDown(() {
    OfflineAssetStore.testOverride = null;
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  Future<(StreamController<FoldersState>, StreamController<SessionState>)> pump(
    WidgetTester tester,
    FoldersState folders,
    SessionState session,
    FoldersRepository repository,
  ) async {
    app_state.prismUser = profileUser(id: session.session.userId, loggedIn: session.session.loggedIn);
    final foldersBloc = _FoldersBloc();
    final sessionBloc = _SessionBloc();
    final foldersStates = StreamController<FoldersState>();
    final sessionStates = StreamController<SessionState>();
    whenListen(foldersBloc, foldersStates.stream, initialState: folders);
    whenListen(sessionBloc, sessionStates.stream, initialState: session);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FoldersBloc>.value(value: foldersBloc),
          BlocProvider<SessionBloc>.value(value: sessionBloc),
        ],
        child: ShortcutsFoldersListener(repository: repository, child: const SizedBox.shrink()),
      ),
    );
    return (foldersStates, sessionStates);
  }

  Future<void> appOpenScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{});
    await _installStore(tester, store);
    final _FakeFoldersRepository repository = _FakeFoldersRepository()..walls['f1'] = <FavouriteWallEntity>[_wall('a')];
    final (foldersStates, sessionStates) = await pump(
      tester,
      _folders('u1', <FolderEntity>[_folder('f1')]),
      _session('u1'),
      repository,
    );

    await _settle(tester, () => store.writes.length == 1, reason: 'app open snapshot');

    final Map<String, dynamic> snapshot = _decode(store.writes.single as String);
    expect(snapshot['ownerId'], 'u1');
    expect((snapshot['folders'] as List<Object?>).cast<Map<String, dynamic>>().map((f) => f['id']), <String>['f1']);

    await _finish(tester, foldersStates, sessionStates);
  }

  Future<void> folderChangeScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{});
    await _installStore(tester, store);
    final _FakeFoldersRepository repository = _FakeFoldersRepository()
      ..walls['f1'] = <FavouriteWallEntity>[_wall('a')]
      ..walls['f2'] = <FavouriteWallEntity>[_wall('b')];
    final (foldersStates, sessionStates) = await pump(
      tester,
      _folders('u1', <FolderEntity>[_folder('f1')]),
      _session('u1'),
      repository,
    );
    await _settle(tester, () => store.writes.length == 1, reason: 'initial snapshot');

    foldersStates.add(_folders('u1', <FolderEntity>[_folder('f1'), _folder('f2')]));
    await _settle(tester, () => true, reason: 'folder edit before debounce');
    expect(store.writes, hasLength(1));

    await tester.pump(ShortcutsFoldersListener.editDebounce);
    await _settle(tester, () => store.writes.length == 2, reason: 'debounced folder edit');
    final Map<String, dynamic> snapshot = _decode(store.writes.last as String);
    expect((snapshot['folders'] as List<Object?>).cast<Map<String, dynamic>>().map((f) => f['id']), <String>[
      'f1',
      'f2',
    ]);

    await _finish(tester, foldersStates, sessionStates);
  }

  Future<void> otherUserScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{});
    await _installStore(tester, store);
    final _FakeFoldersRepository repository = _FakeFoldersRepository()..walls['f1'] = <FavouriteWallEntity>[_wall('a')];
    final (foldersStates, sessionStates) = await pump(
      tester,
      _folders('u2', <FolderEntity>[_folder('f1', owner: 'u2')]),
      _session('u1'),
      repository,
    );

    await _settle(tester, () => true, reason: 'other user folders to be ignored');
    expect(store.writes, isEmpty);
    expect(repository.fetched, isEmpty);

    await _finish(tester, foldersStates, sessionStates);
  }

  Future<void> signOutScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{
      'flutter.${PersistenceKeys.shortcutsRotationFolder}': 'f1',
      'flutter.${PersistenceKeys.shortcutsShuffleBags}': '{"f1":[0]}',
      'flutter.offline.native_asset_paths.folders': '{"https://example.com/a.jpg":"a.jpg"}',
      'flutter.offline.native_asset_paths.category': '{"https://example.com/c.jpg":"c.jpg"}',
      'flutter.offline.native_asset_paths': '{"https://example.com/a.jpg":"a.jpg","https://example.com/c.jpg":"c.jpg"}',
    });
    await _installStore(tester, store);
    final _FakeFoldersRepository repository = _FakeFoldersRepository()..walls['f1'] = <FavouriteWallEntity>[_wall('a')];
    final (foldersStates, sessionStates) = await pump(
      tester,
      _folders('u1', <FolderEntity>[_folder('f1')]),
      _session('u1'),
      repository,
    );
    await _settle(tester, () => store.writes.length == 1, reason: 'signed-in snapshot');
    final SharedPreferences beforeSignOut = await SharedPreferences.getInstance();
    await beforeSignOut.setString('offline.native_asset_paths.folders', '{"https://example.com/a.jpg":"a.jpg"}');
    await beforeSignOut.setString(
      'offline.native_asset_paths',
      '{"https://example.com/a.jpg":"a.jpg","https://example.com/c.jpg":"c.jpg"}',
    );

    app_state.prismUser = profileUser(id: '', loggedIn: false);
    sessionStates.add(_resolvedGuest());
    await _settle(tester, () => store.writes.length == 2, reason: 'sign-out clear');

    expect(store.writes.last, '{"folders":[]}');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PersistenceKeys.shortcutsRotationFolder), isNull);
    expect(prefs.getString(PersistenceKeys.shortcutsShuffleBags), isNull);
    expect(prefs.getString('offline.native_asset_paths.folders'), '{}');
    expect(prefs.getString('offline.native_asset_paths'), '{"https://example.com/c.jpg":"c.jpg"}');

    await _finish(tester, foldersStates, sessionStates);
  }

  Future<void> staleOwnerScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{});
    await _installStore(tester, store);
    final _FakeFoldersRepository repository = _FakeFoldersRepository()..walls['f1'] = <FavouriteWallEntity>[_wall('a')];
    final (foldersStates, sessionStates) = await pump(
      tester,
      FoldersState.initial().copyWith(status: LoadStatus.loading, userId: 'u1'),
      _session('u1'),
      repository,
    );
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    foldersStates.add(_folders('u1', <FolderEntity>[_folder('f1')]));
    await _settle(tester, () => true, reason: 'folders emission after local sign-out');
    await tester.pump(ShortcutsFoldersListener.editDebounce);
    await _settle(tester, () => true, reason: 'debounced sync after local sign-out');

    expect(store.writes, isEmpty);
    expect(repository.fetched, isEmpty);
    await _finish(tester, foldersStates, sessionStates);
  }

  Future<void> rotationSelectionScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{});
    await _installStore(tester, store);
    final _FakeFoldersRepository repository = _FakeFoldersRepository();
    final List<FolderEntity> folders = List<FolderEntity>.generate(60, (index) {
      final String id = 'f$index';
      repository.walls[id] = <FavouriteWallEntity>[_wall(id)];
      return _folder(id, updatedAt: DateTime.utc(2026, 2).add(Duration(minutes: index)));
    });
    final (foldersStates, sessionStates) = await pump(tester, _folders('u1', folders), _session('u1'), repository);
    await _settle(tester, () => store.writes.length == 1, reason: 'initial 50 folders');
    List<String> ids() => (_decode(store.writes.last as String)['folders'] as List<Object?>)
        .cast<Map<String, dynamic>>()
        .map((folder) => folder['id'] as String)
        .toList();
    expect(ids(), hasLength(50));
    expect(ids(), isNot(contains('f0')));
    expect(repository.fetched, hasLength(50));

    await ShortcutsFoldersStore.setRotationFolder('f0');
    await _settle(
      tester,
      () => store.writes.length == 2,
      reason: 'rotation selection snapshot without another bloc emission',
      timeout: const Duration(seconds: 2),
    );

    expect(ids(), hasLength(50));
    expect(ids().toSet(), hasLength(50));
    expect(ids(), contains('f0'));
    expect(ids(), isNot(contains('f10')));
    expect(repository.fetched.skip(50), <String>['f0']);
    final Map<String, dynamic> chosen = (_decode(store.writes.last as String)['folders'] as List<Object?>)
        .cast<Map<String, dynamic>>()
        .singleWhere((folder) => folder['id'] == 'f0');
    expect(chosen['items'], <Map<String, String>>[
      <String, String>{'id': folderItemKey(_wall('f0')), 'url': 'https://example.com/f0.jpg'},
    ]);
    await _finish(tester, foldersStates, sessionStates);
  }

  Future<void> accountSwitchScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{});
    await _installStore(tester, store);
    final _FakeFoldersRepository repository = _FakeFoldersRepository()
      ..walls['a'] = <FavouriteWallEntity>[_wall('a')]
      ..walls['b'] = <FavouriteWallEntity>[_wall('b')];
    final (foldersStates, sessionStates) = await pump(
      tester,
      _folders('u1', <FolderEntity>[_folder('a')]),
      _session('u1'),
      repository,
    );
    await _settle(tester, () => store.writes.length == 1, reason: 'account A snapshot');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PersistenceKeys.shortcutsRotationFolder, 'a');
    await prefs.setString(PersistenceKeys.shortcutsShuffleBags, '{"a":[0]}');

    app_state.prismUser = profileUser(id: 'u2');
    foldersStates.add(_folders('u2', <FolderEntity>[_folder('b', owner: 'u2')]));
    await tester.pump();
    await tester.pump(ShortcutsFoldersListener.editDebounce);
    await _settle(tester, () => true, reason: 'B folders wait for matching session');
    expect(store.writes, hasLength(1));
    expect(repository.fetched, <String>['a']);

    sessionStates.add(_session('u2'));
    await _settle(
      tester,
      () => store.writes.length == 3,
      reason: 'clear A then sync B without another folder event',
      timeout: const Duration(seconds: 2),
    );

    expect(store.writes[1], '{"folders":[]}');
    final Map<String, dynamic> snapshot = _decode(store.writes[2] as String);
    expect(snapshot['ownerId'], 'u2');
    expect((snapshot['folders'] as List<Object?>).cast<Map<String, dynamic>>().single['id'], 'b');
    expect(repository.fetched, <String>['a', 'b']);
    expect(prefs.getString(PersistenceKeys.shortcutsRotationFolder), isNull);
    expect(prefs.getString(PersistenceKeys.shortcutsShuffleBags), isNull);
    await _finish(tester, foldersStates, sessionStates);
  }

  Future<void> resolvedGuestScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{
      'flutter.${PersistenceKeys.shortcutsFolders}': '{"ownerId":"u1","folders":[{"id":"a"}]}',
      'flutter.${PersistenceKeys.shortcutsRotationFolder}': 'a',
      'flutter.${PersistenceKeys.shortcutsShuffleBags}': '{"a":[0]}',
      'flutter.offline.native_asset_paths.folders': '{"https://example.com/a.jpg":"a.jpg"}',
      'flutter.offline.native_asset_paths.category': '{"https://example.com/c.jpg":"c.jpg"}',
      'flutter.offline.native_asset_paths': '{"https://example.com/a.jpg":"a.jpg","https://example.com/c.jpg":"c.jpg"}',
    });
    await _installStore(tester, store);
    final _FakeFoldersRepository repository = _FakeFoldersRepository();
    final (foldersStates, sessionStates) = await pump(
      tester,
      _folders('u1', <FolderEntity>[_folder('a')]),
      _resolvedGuest(),
      repository,
    );
    await _settle(
      tester,
      () => store.writes.isNotEmpty,
      reason: 'resolved guest clears stale account snapshot',
      timeout: const Duration(seconds: 2),
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(store.writes.single, '{"folders":[]}');
    expect(prefs.getString(PersistenceKeys.shortcutsRotationFolder), isNull);
    expect(prefs.getString(PersistenceKeys.shortcutsShuffleBags), isNull);
    expect(prefs.getString('offline.native_asset_paths.folders'), '{}');
    expect(prefs.getString('offline.native_asset_paths.category'), '{"https://example.com/c.jpg":"c.jpg"}');
    expect(prefs.getString('offline.native_asset_paths'), '{"https://example.com/c.jpg":"c.jpg"}');
    expect(repository.fetched, isEmpty);
    await _finish(tester, foldersStates, sessionStates);
  }

  testWidgets('on iOS folder snapshots follow the signed-in user and rotation selection', (tester) async {
    // The native store retains its write-tail Future. Keep its scenarios in one FakeAsync zone.
    await appOpenScenario(tester);
    await folderChangeScenario(tester);
    await otherUserScenario(tester);
    await signOutScenario(tester);
    await staleOwnerScenario(tester);
    await rotationSelectionScenario(tester);
    await accountSwitchScenario(tester);
    await resolvedGuestScenario(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on Android it writes nothing', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.runAsync(() => SharedPreferences.getInstance());
    final _FakeFoldersRepository repository = _FakeFoldersRepository()..walls['f1'] = <FavouriteWallEntity>[_wall('a')];
    final (foldersStates, sessionStates) = await pump(
      tester,
      _folders('u1', <FolderEntity>[_folder('f1')]),
      _session('u1'),
      repository,
    );

    foldersStates.add(_folders('u1', <FolderEntity>[_folder('f1'), _folder('f2')]));
    await _settle(tester, () => true, reason: 'Android folders event');
    sessionStates.add(_resolvedGuest());
    await _settle(tester, () => true, reason: 'Android sign-out event');

    expect(await _stored(), isNull);
    expect(repository.fetched, isEmpty);

    await _finish(tester, foldersStates, sessionStates, drainWrites: false);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
