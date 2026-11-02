import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFoldersRepository implements FoldersRepository {
  List<FolderEntity> folders = <FolderEntity>[];
  Map<String, List<FavouriteWallEntity>> items = <String, List<FavouriteWallEntity>>{};
  final List<String> calls = <String>[];
  final List<int?> fetchItemLimits = <int?>[];
  bool fail = false;
  bool failItems = false;
  Future<Result<List<FolderEntity>>> Function(String)? fetchFoldersOverride;
  Completer<Result<void>>? addGate;
  final writeFailureController = StreamController<FolderWriteFailure>.broadcast();
  @override
  Stream<FolderWriteFailure> get writeFailures => writeFailureController.stream;
  @override
  int writeRevision = 0;
  String? failAddFolderId;
  String? failCreateName;
  void Function()? afterAdd;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async {
    if (fetchFoldersOverride case final fetch?) return fetch(userId);
    if (fail) return Result.error<List<FolderEntity>>(const ServerFailure('boom'));
    return Result.success(folders.where((folder) => folder.ownerId == userId).toList());
  }

  @override
  Future<Result<List<FavouriteWallEntity>?>> fetchItems(String folderId, {required String userId, int? limit}) async {
    fetchItemLimits.add(limit);
    if (fail || failItems) return Result.error<List<FavouriteWallEntity>?>(const ServerFailure('boom'));
    if (folders.every((folder) => folder.id != folderId)) return Result.success(null);
    final List<FavouriteWallEntity> list = items[folderId] ?? <FavouriteWallEntity>[];
    return Result.success(limit == null ? list : list.take(limit).toList());
  }

  @override
  Future<Result<Set<String>>> foldersContaining(List<String> folderIds, String itemKey) async {
    if (fail) return Result.error<Set<String>>(const ServerFailure('boom'));
    return Result.success(
      folderIds
          .where((id) => (items[id] ?? const <FavouriteWallEntity>[]).any((item) => folderItemKey(item) == itemKey))
          .toSet(),
    );
  }

  @override
  Future<Result<void>> createFolder(FolderEntity folder, {FavouriteWallEntity? firstWall}) async {
    calls.add('createFolder:${folder.name}:${folder.itemCount}:${firstWall != null}');
    if (fail || folder.name == failCreateName) return Result.error<void>(const ServerFailure('boom'));
    folders = <FolderEntity>[...folders, folder];
    items[folder.id] = <FavouriteWallEntity>[?firstWall];
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> renameFolder(FolderEntity folder) async {
    calls.add('renameFolder:${folder.id}:${folder.name}');
    if (fail) return Result.error<void>(const ServerFailure('boom'));
    folders = folders.map((other) => other.id == folder.id ? folder : other).toList();
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> deleteFolder(String folderId, {required String userId, bool Function()? isCancelled}) async {
    calls.add('deleteFolder:$folderId');
    if (fail) return Result.error<void>(const ServerFailure('boom'));
    folders = folders.where((folder) => folder.id != folderId).toList();
    items.remove(folderId);
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall) async {
    calls.add('addItem:${folder.id}:${folder.itemCount}:${folder.covers.join(',')}');
    if (addGate case final gate?) {
      final Result<void> result = await gate.future;
      if (result.isFailure) return result;
    }
    if (fail || folder.id == failAddFolderId) return Result.error<void>(const ServerFailure('boom'));
    _replaceFolder(folder);
    final List<FavouriteWallEntity> existing = items[folder.id] ?? <FavouriteWallEntity>[];
    items[folder.id] = <FavouriteWallEntity>[
      wall,
      ...existing.where((item) => folderItemKey(item) != folderItemKey(wall)),
    ];
    afterAdd?.call();
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall) async {
    calls.add('removeItem:${folder.id}:${folder.itemCount}:${folder.covers.join(',')}');
    if (fail) return Result.error<void>(const ServerFailure('boom'));
    _replaceFolder(folder);
    final List<FavouriteWallEntity> existing = items[folder.id] ?? <FavouriteWallEntity>[];
    items[folder.id] = existing.where((item) => folderItemKey(item) != folderItemKey(wall)).toList();
    return Result.success<void>(null);
  }

  void _replaceFolder(FolderEntity folder) {
    folders = folders.map((other) => other.id == folder.id ? folder : other).toList();
  }
}

String thumb(String id) => 'https://x/$id-t.jpg';

PrismFavouriteWall wall(String id, {String? thumbUrl}) => PrismFavouriteWall(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://x/$id.jpg',
      thumbnailUrl: thumbUrl ?? thumb(id),
    ),
  ),
);

WallhavenFavouriteWall wallhavenWall(String id) => WallhavenFavouriteWall(
  id: id,
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://x/wh-$id.jpg',
      thumbnailUrl: 'https://x/wh-$id-t.jpg',
    ),
  ),
);

FolderEntity folder(String id, {int count = 0, List<String> covers = const <String>[], DateTime? updated}) =>
    FolderEntity(
      id: id,
      ownerId: 'u1',
      name: 'F-$id',
      createdAt: DateTime.utc(2026),
      updatedAt: updated ?? DateTime.utc(2026),
      itemCount: count,
      covers: covers,
    );

FoldersBloc _blocFor(_FakeFoldersRepository repo) {
  final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
  addTearDown(repo.writeFailureController.close);
  addTearDown(bloc.close);
  return bloc;
}

Future<bool> _started(FoldersBloc bloc, {String userId = 'u1'}) =>
    bloc.run((id) => FoldersEvent.started(userId: userId, operationId: id));

class _NoPublicFolders implements PublicFoldersRepository {
  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => Result.success<PublicFolderEntity?>(null);

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async => Result.success(<String>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId) async =>
      Result.success(<PublicFolderEntity>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId) async =>
      Result.success(<PublicFolderEntity>[]);

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) async => Result.success(false);

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async => Result.success<void>(null);

  @override
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic}) async => Result.success(isPublic);
}

void main() {
  test('sign-out between completed Save steps does not start the next write', () async {
    final repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a'), folder('b')];
    final bloc = _blocFor(repo);
    await _started(bloc);
    repo.afterAdd = () => scheduleMicrotask(() => bloc.add(const FoldersEvent.cleared()));

    expect(
      await bloc.run(
        (id) => FoldersEvent.saveRequested(wall: wall('w1'), folderIds: <String>{'a', 'b'}, operationId: id),
      ),
      isFalse,
    );
    await pumpEventQueue();
    expect(repo.calls, <String>['addItem:a:1:${thumb('w1')}']);
    expect(bloc.state, FoldersState.initial());
  });

  test('retry resumes created folders rather than duplicating a partial Save', () async {
    final repo = _FakeFoldersRepository()..failCreateName = 'B';
    final bloc = _blocFor(repo);
    await _started(bloc);
    Future<bool> save() => bloc.run(
      (id) => FoldersEvent.saveRequested(
        wall: wall('w1'),
        folderIds: <String>{},
        newNames: <String>['A', 'B'],
        operationId: id,
      ),
    );
    expect(await save(), isFalse);
    repo.failCreateName = null;
    expect(await save(), isTrue);
    expect(bloc.state.folders.map((folder) => folder.name).toList()..sort(), <String>['A', 'B']);
    expect(bloc.state.folders.every((folder) => folder.itemCount == 1), isTrue);
    expect(repo.calls.where((call) => call == 'createFolder:A:1:true'), hasLength(1));
    expect(repo.calls.where((call) => call.startsWith('removeItem:')), isEmpty);
  });

  test('refresh invalidates old membership before saving an externally added wall', () async {
    final repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a')];
    final bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));
    repo.folders = <FolderEntity>[folder('a', count: 1)];
    repo.items['a'] = <FavouriteWallEntity>[wall('w1')];
    await _started(bloc);
    expect(
      await bloc.run((id) => FoldersEvent.saveRequested(wall: wall('w1'), folderIds: <String>{'a'}, operationId: id)),
      isTrue,
    );
    expect(repo.calls, isEmpty);
    expect(bloc.state.folder('a')?.itemCount, 1);
  });

  test('late rejection from an earlier login of the same user is ignored', () async {
    final repo = _FakeFoldersRepository();
    final bloc = _blocFor(repo);
    await _started(bloc);
    repo.writeRevision = 1;
    bloc.add(const FoldersEvent.cleared());
    await _started(bloc);
    final before = bloc.state;
    repo.writeFailureController.add((ownerId: 'u1', revision: 1, failure: const ServerFailure('old login')));
    await pumpEventQueue();
    expect(bloc.state, before);
  });

  test('each pending late failure invalidates a subsequent reload', () async {
    final repo = _FakeFoldersRepository();
    final bloc = _blocFor(repo);
    await _started(bloc);
    repo.writeRevision = 2;
    repo.writeFailureController.add((ownerId: 'u1', revision: 1, failure: const ServerFailure('first')));
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.failure);
    await _started(bloc);
    expect(bloc.state.status, LoadStatus.success);
    repo.writeFailureController.add((ownerId: 'u1', revision: 2, failure: const ServerFailure('second')));
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.failure?.message, 'second');
  });

  test('late queued rejection clears optimistic caches only for its owner', () async {
    final repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a', count: 1)]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1')],
      };
    final bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id));
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));
    final before = bloc.state;
    repo.writeRevision = 1;
    repo.writeFailureController.add((ownerId: 'u2', revision: 1, failure: const ServerFailure('other user')));
    await pumpEventQueue();
    expect(bloc.state, before);

    repo.writeFailureController.add((ownerId: 'u1', revision: 1, failure: const ServerFailure('queued rejected')));
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.actionStatus, ActionStatus.failure);
    expect(bloc.state.failure?.message, 'queued rejected');
    expect(bloc.state.items, isEmpty);
    expect(bloc.state.membership, isEmpty);
    expect(bloc.state.folders, isEmpty);
  });

  test('a repeated removal from an unopened folder does not decrement twice', () async {
    final repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a', count: 2)]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1'), wall('w2')],
      };
    final bloc = _blocFor(repo);
    await _started(bloc);
    for (var i = 0; i < 2; i++) {
      expect(
        await bloc.run((id) => FoldersEvent.itemRemoved(folderId: 'a', wall: wall('w1'), operationId: id)),
        isTrue,
      );
    }
    expect(bloc.state.folder('a')?.itemCount, 1);
    expect(repo.calls, hasLength(1));
  });

  test('cleared cancels an in-flight load and its run without waiting for the network', () async {
    final pending = Completer<Result<List<FolderEntity>>>();
    final repo = _FakeFoldersRepository()..fetchFoldersOverride = (_) => pending.future;
    final bloc = _blocFor(repo);
    final loading = _started(bloc);
    await pumpEventQueue();

    bloc.add(const FoldersEvent.cleared());
    await pumpEventQueue();
    final stateAfterClear = bloc.state;
    pending.complete(Result.success(<FolderEntity>[folder('private')]));

    expect(await loading, isFalse);
    await pumpEventQueue();
    expect(stateAfterClear, FoldersState.initial());
    expect(bloc.state, FoldersState.initial());
  });

  test('a new user loads without waiting for the previous user and ignores the old response', () async {
    final pending = Completer<Result<List<FolderEntity>>>();
    final repo = _FakeFoldersRepository()
      ..fetchFoldersOverride = (userId) =>
          userId == 'u1' ? pending.future : Future.value(Result.success(<FolderEntity>[]));
    final bloc = _blocFor(repo);
    final oldLoad = _started(bloc);
    await pumpEventQueue();
    final newLoad = _started(bloc, userId: 'u2');
    await pumpEventQueue();
    final stateAfterSwitch = bloc.state;
    pending.complete(Result.success(<FolderEntity>[folder('private')]));

    expect(await oldLoad, isFalse);
    expect(await newLoad, isTrue);
    expect(stateAfterSwitch.userId, 'u2');
    expect(stateAfterSwitch.status, LoadStatus.success);
    expect(bloc.state.userId, 'u2');
    expect(bloc.state.folders, isEmpty);
  });

  test('clear drops queued saves and stops the remaining writes of an active save', () async {
    final gate = Completer<Result<void>>();
    final repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a'), folder('b')]
      ..addGate = gate;
    final bloc = _blocFor(repo);
    await _started(bloc);
    final first = bloc.run(
      (id) => FoldersEvent.saveRequested(wall: wall('w1'), folderIds: <String>{'a', 'b'}, operationId: id),
    );
    await pumpEventQueue();
    final queued = bloc.run(
      (id) => FoldersEvent.saveRequested(wall: wall('w2'), folderIds: <String>{'a'}, operationId: id),
    );
    bloc.add(const FoldersEvent.cleared());
    await pumpEventQueue();
    final stateAfterClear = bloc.state;
    gate.complete(Result.success<void>(null));

    expect(await first, isFalse);
    expect(await queued, isFalse);
    await pumpEventQueue();
    expect(stateAfterClear, FoldersState.initial());
    expect(bloc.state, FoldersState.initial());
    expect(repo.calls, <String>['addItem:a:1:${thumb('w1')}']);
  });

  test('a failed cover read does not remove an unloaded item or change its count', () async {
    final repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[
        folder('a', count: 2, covers: <String>[thumb('w1'), thumb('w2')]),
      ]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1'), wall('w2')],
      };
    final bloc = _blocFor(repo);
    await _started(bloc);
    repo.failItems = true;

    expect(await bloc.run((id) => FoldersEvent.itemRemoved(folderId: 'a', wall: wall('w1'), operationId: id)), isFalse);
    expect(repo.calls, isEmpty);
    expect(bloc.state.folder('a')?.itemCount, 2);
    expect(bloc.state.folder('a')?.covers, <String>[thumb('w1'), thumb('w2')]);

    repo.failItems = false;
    expect(await bloc.run((id) => FoldersEvent.itemRemoved(folderId: 'a', wall: wall('w1'), operationId: id)), isTrue);
    expect(repo.items['a']?.map((item) => item.id).toList(), <String>['w2']);
    expect(bloc.state.folder('a')?.itemCount, 1);
    expect(bloc.state.folder('a')?.covers, <String>[thumb('w2')]);
    expect(bloc.state.items.containsKey('a'), isFalse);
    expect(repo.fetchItemLimits, <int?>[folderMaxCovers + 1, folderMaxCovers + 1]);
  });

  test('opening a removed folder clears previously loaded items and membership', () async {
    final repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a', count: 1)]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1')],
      };
    final bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id));
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));
    repo.folders = <FolderEntity>[];

    expect(await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id)), isTrue);
    expect(bloc.state.items.containsKey('a'), isFalse);
    expect(bloc.state.membership[folderItemKey(wall('w1'))], isEmpty);
  });

  test("started loads the user's folders newest update first", () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[
        folder('jan1', updated: DateTime.utc(2026)),
        folder('jan2', updated: DateTime.utc(2026, 1, 2)),
      ];
    final FoldersBloc bloc = _blocFor(repo);

    expect(await _started(bloc), isTrue);

    expect(bloc.state.folders.map((f) => f.id).toList(), <String>['jan2', 'jan1']);
    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.userId, 'u1');
  });

  test('started failure sets LoadStatus.failure and run() returns false', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..fail = true;
    final FoldersBloc bloc = _blocFor(repo);

    expect(await _started(bloc), isFalse);

    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.failure?.message, 'boom');
  });

  test('cleared resets to FoldersState.initial()', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a')];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    expect(bloc.state.folders, hasLength(1));

    bloc.add(const FoldersEvent.cleared());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, FoldersState.initial());
    expect(bloc.state.folders, isEmpty);
    expect(bloc.state.userId, '');
  });

  test("started for a different user drops the old user's folders, items and membership", () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a')]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1')],
      };
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id));
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));
    expect(bloc.state.items, hasLength(1));
    expect(bloc.state.membership, hasLength(1));

    expect(await _started(bloc, userId: 'u2'), isTrue);

    expect(bloc.state.userId, 'u2');
    expect(bloc.state.folders, isEmpty);
    expect(bloc.state.items, isEmpty);
    expect(bloc.state.membership, isEmpty);
  });

  test('createRequested without a wall adds an empty folder with a trimmed name', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository();
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    expect(await bloc.run((id) => FoldersEvent.createRequested(name: '  Blue  ', operationId: id)), isTrue);

    expect(bloc.state.folders, hasLength(1));
    final FolderEntity created = bloc.state.folders.single;
    expect(created.name, 'Blue');
    expect(created.itemCount, 0);
    expect(created.covers, isEmpty);
    expect(created.ownerId, 'u1');
    expect(repo.calls, <String>['createFolder:Blue:0:false']);
  });

  test('createRequested with an empty or 51 character name returns false and makes no repo call', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository();
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    expect(await bloc.run((id) => FoldersEvent.createRequested(name: '', operationId: id)), isFalse);
    expect(await bloc.run((id) => FoldersEvent.createRequested(name: 'x' * 51, operationId: id)), isFalse);

    expect(repo.calls, isEmpty);
    expect(bloc.state.folders, isEmpty);
  });

  test('saveRequested adds the wall to two existing folders at once', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a'), folder('b')];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    expect(
      await bloc.run(
        (id) => FoldersEvent.saveRequested(wall: wall('w1'), folderIds: <String>{'a', 'b'}, operationId: id),
      ),
      isTrue,
    );

    expect(bloc.state.folder('a')?.itemCount, 1);
    expect(bloc.state.folder('a')?.covers, <String>[thumb('w1')]);
    expect(bloc.state.folder('b')?.itemCount, 1);
    expect(bloc.state.folder('b')?.covers, <String>[thumb('w1')]);
    expect(bloc.state.membership[folderItemKey(wall('w1'))], <String>{'a', 'b'});
    expect(repo.calls, <String>['addItem:a:1:${thumb('w1')}', 'addItem:b:1:${thumb('w1')}']);
  });

  test('saveRequested with newNames creates the folder with the wall inside', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository();
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    expect(
      await bloc.run(
        (id) => FoldersEvent.saveRequested(
          wall: wall('w1'),
          folderIds: const <String>{},
          newNames: const <String>['New'],
          operationId: id,
        ),
      ),
      isTrue,
    );

    expect(bloc.state.folders, hasLength(1));
    final FolderEntity created = bloc.state.folders.single;
    expect(created.itemCount, 1);
    expect(created.covers, <String>[thumb('w1')]);
    expect(bloc.state.membership[folderItemKey(wall('w1'))], <String>{created.id});
    expect(repo.calls, <String>['createFolder:New:1:true']);
  });

  test('saveRequested removes the wall from a folder it is unticked in and refills covers', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[
        folder('a', count: 5, covers: <String>[thumb('w1'), thumb('w2'), thumb('w3'), thumb('w4')]),
      ]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1'), wall('w2'), wall('w3'), wall('w4'), wall('w5')],
      };
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));
    expect(bloc.state.membership[folderItemKey(wall('w1'))], <String>{'a'});

    expect(
      await bloc.run(
        (id) => FoldersEvent.saveRequested(wall: wall('w1'), folderIds: const <String>{}, operationId: id),
      ),
      isTrue,
    );

    expect(bloc.state.folder('a')?.itemCount, 4);
    expect(bloc.state.folder('a')?.covers, <String>[thumb('w2'), thumb('w3'), thumb('w4'), thumb('w5')]);
    expect(bloc.state.membership[folderItemKey(wall('w1'))], isEmpty);
    expect(repo.calls, <String>['removeItem:a:4:${thumb('w2')},${thumb('w3')},${thumb('w4')},${thumb('w5')}']);
  });

  test('saveRequested removes an externally added wall despite a cached empty folder', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a')];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id));
    expect(bloc.state.items['a'], isEmpty);

    repo.items['a'] = <FavouriteWallEntity>[wall('w1')];
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));
    expect(bloc.state.membership[folderItemKey(wall('w1'))], <String>{'a'});

    expect(
      await bloc.run(
        (id) => FoldersEvent.saveRequested(wall: wall('w1'), folderIds: const <String>{}, operationId: id),
      ),
      isTrue,
    );

    expect(repo.items['a'], isEmpty);
    expect(repo.calls, <String>['removeItem:a:0:']);
    expect(repo.fetchItemLimits, <int?>[null, folderMaxCovers + 1]);
    expect(bloc.state.membership[folderItemKey(wall('w1'))], isEmpty);
    expect(bloc.state.items['a'], isEmpty);
    expect(bloc.state.folder('a')?.itemCount, 0);
  });

  test('removing an externally added wall preserves the full opened item cache', () async {
    final List<FavouriteWallEntity> originalItems = <FavouriteWallEntity>[
      wall('w1'),
      wall('w2'),
      wall('w3'),
      wall('w4'),
      wall('w5'),
      wall('w6'),
    ];
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a', count: originalItems.length)]
      ..items = <String, List<FavouriteWallEntity>>{'a': originalItems};
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id));
    expect(bloc.state.items['a']?.map((item) => item.id).toList(), <String>['w1', 'w2', 'w3', 'w4', 'w5', 'w6']);
    expect(repo.fetchItemLimits, <int?>[null]);

    final FavouriteWallEntity addedWall = wall('new');
    repo.items['a'] = <FavouriteWallEntity>[addedWall, ...originalItems];
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: addedWall, operationId: id));
    expect(bloc.state.membership[folderItemKey(addedWall)], <String>{'a'});

    expect(
      await bloc.run((id) => FoldersEvent.saveRequested(wall: addedWall, folderIds: const <String>{}, operationId: id)),
      isTrue,
    );

    expect(repo.fetchItemLimits, <int?>[null, folderMaxCovers + 1]);
    expect(repo.items['a']?.map((item) => item.id).toList(), <String>['w1', 'w2', 'w3', 'w4', 'w5', 'w6']);
    expect(bloc.state.folder('a')?.covers, <String>[thumb('w1'), thumb('w2'), thumb('w3'), thumb('w4')]);
    expect(bloc.state.items['a']?.map((item) => item.id).toList(), <String>['w1', 'w2', 'w3', 'w4', 'w5', 'w6']);
  });

  test('saveRequested evicts stale state when the folder vanishes during the cover read', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[
        folder('a', count: 1, covers: <String>[thumb('w1')]),
      ]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1')],
      };
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));
    expect(bloc.state.membership[folderItemKey(wall('w1'))], <String>{'a'});

    repo.folders = <FolderEntity>[];
    expect(
      await bloc.run(
        (id) => FoldersEvent.saveRequested(wall: wall('w1'), folderIds: const <String>{}, operationId: id),
      ),
      isFalse,
    );

    expect(bloc.state.failure, isA<ValidationFailure>());
    expect(repo.calls, isEmpty);
    expect(bloc.state.folder('a'), isNull);
    expect(bloc.state.items.containsKey('a'), isFalse);
    expect(bloc.state.itemsStatus['a'], LoadStatus.success);
    expect(bloc.state.membership[folderItemKey(wall('w1'))], isEmpty);
  });

  test('covers stay at 4, newest first, and a re-added thumb is not duplicated', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[
        folder('a', count: 4, covers: <String>[thumb('w1'), thumb('w2'), thumb('w3'), thumb('w4')]),
      ];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    await bloc.run((id) => FoldersEvent.saveRequested(wall: wall('w5'), folderIds: <String>{'a'}, operationId: id));
    expect(bloc.state.folder('a')?.itemCount, 5);
    expect(bloc.state.folder('a')?.covers, <String>[thumb('w5'), thumb('w1'), thumb('w2'), thumb('w3')]);

    await bloc.run(
      (id) => FoldersEvent.saveRequested(
        wall: wall('w9', thumbUrl: thumb('w2')),
        folderIds: <String>{'a'},
        operationId: id,
      ),
    );
    expect(bloc.state.folder('a')?.itemCount, 6);
    expect(bloc.state.folder('a')?.covers, <String>[thumb('w2'), thumb('w5'), thumb('w1'), thumb('w3')]);
  });

  test('count never goes below 0', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a')];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    expect(await bloc.run((id) => FoldersEvent.itemRemoved(folderId: 'a', wall: wall('w1'), operationId: id)), isTrue);

    expect(bloc.state.folder('a')?.itemCount, 0);
    expect(repo.calls, isEmpty);
  });

  test('folderOpened loads the folder items', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a', count: 2)]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1'), wall('w2')],
      };
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    expect(await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id)), isTrue);

    expect(bloc.state.items['a']?.map((item) => item.id).toList(), <String>['w1', 'w2']);
    expect(bloc.state.itemsStatus['a'], LoadStatus.success);
  });

  test('folderOpened removes a folder that fetchItems reports as gone', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a'), folder('ghost')];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    repo.folders = repo.folders.where((folder) => folder.id != 'ghost').toList();

    expect(await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'ghost', operationId: id)), isTrue);

    expect(bloc.state.folder('ghost'), isNull);
    expect(bloc.state.folder('a'), isNotNull);
    expect(bloc.state.items.containsKey('ghost'), isFalse);
    expect(bloc.state.itemsStatus['ghost'], LoadStatus.success);
  });

  test('opening a missing folder clears cached items and memberships after a list refresh', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a', count: 1)]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1')],
      };
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id));
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));

    repo.folders = <FolderEntity>[];
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'b', operationId: id));
    expect(bloc.state.folder('a'), isNull);
    expect(bloc.state.items['a'], hasLength(1));
    expect(bloc.state.membership[folderItemKey(wall('w1'))], <String>{'a'});

    expect(await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id)), isTrue);

    expect(bloc.state.items.containsKey('a'), isFalse);
    expect(bloc.state.itemsStatus['a'], LoadStatus.success);
    expect(bloc.state.membership[folderItemKey(wall('w1'))], isEmpty);
  });

  test('itemRemoved from an opened folder updates items, count and covers without a limited fetch', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[
        folder('a', count: 3, covers: <String>[thumb('w1'), thumb('w2'), thumb('w3')]),
      ]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1'), wall('w2'), wall('w3')],
      };
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id));

    expect(await bloc.run((id) => FoldersEvent.itemRemoved(folderId: 'a', wall: wall('w2'), operationId: id)), isTrue);

    expect(bloc.state.items['a']?.map((item) => item.id).toList(), <String>['w1', 'w3']);
    expect(bloc.state.folder('a')?.itemCount, 2);
    expect(bloc.state.folder('a')?.covers, <String>[thumb('w1'), thumb('w3')]);
    expect(repo.fetchItemLimits, <int?>[null]);
  });

  test('renameRequested keeps the id and updates the name; an empty name returns false', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a')];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    expect(
      await bloc.run((id) => FoldersEvent.renameRequested(folderId: 'a', name: '  New name ', operationId: id)),
      isTrue,
    );
    expect(bloc.state.folder('a')?.id, 'a');
    expect(bloc.state.folder('a')?.name, 'New name');
    expect(repo.calls, <String>['renameFolder:a:New name']);

    expect(await bloc.run((id) => FoldersEvent.renameRequested(folderId: 'a', name: '', operationId: id)), isFalse);
    expect(bloc.state.folder('a')?.name, 'New name');
    expect(repo.calls, hasLength(1));
  });

  test('deleteRequested removes the folder, its items and its id from every membership set', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()
      ..folders = <FolderEntity>[folder('a', count: 1), folder('b', count: 1)]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[wall('w1')],
        'b': <FavouriteWallEntity>[wall('w1')],
      };
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: 'a', operationId: id));
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));
    expect(bloc.state.membership[folderItemKey(wall('w1'))], <String>{'a', 'b'});

    expect(await bloc.run((id) => FoldersEvent.deleteRequested(folderId: 'a', operationId: id)), isTrue);

    expect(bloc.state.folders.map((f) => f.id).toList(), <String>['b']);
    expect(bloc.state.items.containsKey('a'), isFalse);
    expect(bloc.state.itemsStatus.containsKey('a'), isFalse);
    expect(bloc.state.membership[folderItemKey(wall('w1'))], <String>{'b'});
    expect(repo.calls, <String>['deleteFolder:a']);
  });

  test('a Prism wall and a Wallhaven wall with the same id get different membership keys', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a')];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);

    expect(folderItemKey(wall('abc')), 'prism_abc');
    expect(folderItemKey(wallhavenWall('abc')), 'wallhaven_abc');

    expect(
      await bloc.run((id) => FoldersEvent.saveRequested(wall: wall('abc'), folderIds: <String>{'a'}, operationId: id)),
      isTrue,
    );
    expect(
      await bloc.run((id) => FoldersEvent.membershipRequested(wall: wallhavenWall('abc'), operationId: id)),
      isTrue,
    );

    expect(bloc.state.membership['prism_abc'], <String>{'a'});
    expect(bloc.state.membership['wallhaven_abc'], isEmpty);
  });

  test('with the repo failing, saveRequested returns false and state.folders is unchanged', () async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..folders = <FolderEntity>[folder('a')];
    final FoldersBloc bloc = _blocFor(repo);
    await _started(bloc);
    await bloc.run((id) => FoldersEvent.membershipRequested(wall: wall('w1'), operationId: id));

    repo.fail = true;
    expect(
      await bloc.run((id) => FoldersEvent.saveRequested(wall: wall('w1'), folderIds: <String>{'a'}, operationId: id)),
      isFalse,
    );

    expect(bloc.state.folders.map((f) => f.id).toList(), <String>['a']);
    expect(bloc.state.folder('a')?.itemCount, 0);
    expect(bloc.state.folder('a')?.covers, isEmpty);
    expect(bloc.state.failure?.message, 'boom');
  });
}
