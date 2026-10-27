import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFoldersRepository implements FoldersRepository {
  List<FolderEntity> folders = <FolderEntity>[];
  Map<String, List<FavouriteWallEntity>> items = <String, List<FavouriteWallEntity>>{};
  final List<String> calls = <String>[];
  final List<int?> fetchItemLimits = <int?>[];
  bool fail = false;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async {
    if (fail) return Result.error<List<FolderEntity>>(const ServerFailure('boom'));
    return Result.success(folders.where((folder) => folder.ownerId == userId).toList());
  }

  @override
  Future<Result<List<FavouriteWallEntity>?>> fetchItems(String folderId, {int? limit}) async {
    fetchItemLimits.add(limit);
    if (fail) return Result.error<List<FavouriteWallEntity>?>(const ServerFailure('boom'));
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
    if (fail) return Result.error<void>(const ServerFailure('boom'));
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
  Future<Result<void>> deleteFolder(String folderId) async {
    calls.add('deleteFolder:$folderId');
    if (fail) return Result.error<void>(const ServerFailure('boom'));
    folders = folders.where((folder) => folder.id != folderId).toList();
    items.remove(folderId);
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall) async {
    calls.add('addItem:${folder.id}:${folder.itemCount}:${folder.covers.join(',')}');
    if (fail) return Result.error<void>(const ServerFailure('boom'));
    _replaceFolder(folder);
    final List<FavouriteWallEntity> existing = items[folder.id] ?? <FavouriteWallEntity>[];
    items[folder.id] = <FavouriteWallEntity>[
      wall,
      ...existing.where((item) => folderItemKey(item) != folderItemKey(wall)),
    ];
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
  final FoldersBloc bloc = FoldersBloc(repo);
  addTearDown(bloc.close);
  return bloc;
}

Future<bool> _started(FoldersBloc bloc, {String userId = 'u1'}) =>
    bloc.run((id) => FoldersEvent.started(userId: userId, operationId: id));

void main() {
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
    expect(repo.calls, <String>['removeItem:a:0:']);
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
