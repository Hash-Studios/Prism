import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
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

FolderEntity _folder(String id, {String owner = 'u1'}) => FolderEntity(
  id: id,
  ownerId: owner,
  name: 'Folder $id',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 2),
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

Future<void> _settle(WidgetTester tester, bool Function() isReady, {required String reason}) async {
  await tester.runAsync(() => Future<void>(() {}));
  await tester.pump();
  await waitForRealIo(tester, isReady, reason: reason);
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
  StreamController<SessionState> session,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await folders.close();
  await session.close();
  await tester.runAsync(() => Future<void>(() {}));
  await tester.pump();
}

Map<String, dynamic> _decode(String json) => jsonDecode(json) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    OfflineAssetStore.testOverride = _EmptyOfflineAssetStore();
  });

  tearDown(() {
    OfflineAssetStore.testOverride = null;
  });

  Future<(StreamController<FoldersState>, StreamController<SessionState>)> pump(
    WidgetTester tester,
    FoldersState folders,
    SessionState session,
    FoldersRepository repository,
  ) async {
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

    sessionStates.add(_resolvedGuest());
    await _settle(tester, () => store.writes.length == 2, reason: 'sign-out clear');

    expect(store.writes.last, '{"folders":[]}');
    expect((await SharedPreferences.getInstance()).getString(PersistenceKeys.shortcutsRotationFolder), isNull);

    await _finish(tester, foldersStates, sessionStates);
  }

  testWidgets('on iOS folder snapshots follow the signed-in user', (tester) async {
    await appOpenScenario(tester);
    await folderChangeScenario(tester);
    await otherUserScenario(tester);
    await signOutScenario(tester);
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

    await _finish(tester, foldersStates, sessionStates);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
