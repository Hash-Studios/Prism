import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/domain/entities/folder_edit.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_member.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _OrganizeCall = ({String folderId, String userId, List<FolderSection>? sections, Map<String, String?> moves});

class _FakeOrganizeRepository extends Fake implements FoldersRepository {
  List<FolderEntity> folders = <FolderEntity>[];
  Map<String, List<FavouriteWallEntity>> items = <String, List<FavouriteWallEntity>>{};

  /// Item key to the section it is in. Items not listed have no section.
  Map<String, String> sectionOfWall = <String, String>{};
  Future<Result<List<FolderEntity>>> Function(String userId)? fetchFoldersOverride;
  Result<void> organizeResult = Result.success<void>(null);
  bool failItems = false;
  final List<_OrganizeCall> organizeCalls = <_OrganizeCall>[];
  @override
  int writeRevision = 0;

  @override
  Stream<FolderWriteFailure> get writeFailures => const Stream<FolderWriteFailure>.empty();

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async {
    if (fetchFoldersOverride case final fetch?) return fetch(userId);
    return Result.success(folders.where((folder) => folder.roleOf(userId) != null).toList());
  }

  @override
  Future<Result<List<FolderItem>?>> fetchItems(String folderId, {required String userId, int? limit}) async {
    if (failItems) return Result.error(const ServerFailure('read failed'));
    if (folders.every((folder) => folder.id != folderId)) return Result.success(null);
    final List<FavouriteWallEntity> list = items[folderId] ?? <FavouriteWallEntity>[];
    return Result.success(list.map((w) => FolderItem(w, sectionId: sectionOfWall[folderItemKey(w)])).toList());
  }

  @override
  Future<Result<void>> organize(
    FolderEntity folder, {
    required String userId,
    List<FolderSection>? sections,
    Map<String, String?> moves = const <String, String?>{},
  }) async {
    organizeCalls.add((folderId: folder.id, userId: userId, sections: sections, moves: moves));
    return organizeResult;
  }
}

class _NoPublicFolders extends Fake implements PublicFoldersRepository {
  @override
  Future<Result<Set<String>>> fetchFollowedIds(String userId) async => Result.success(<String>{});

  @override
  Future<Result<FolderDiscoverLists>> fetchDiscover() async => Result.success(FolderDiscoverLists.empty);

  @override
  Future<void> recordSignal(String folderId, FolderSignal signal) async {}

  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => Result.success<PublicFolderEntity?>(null);

  @override
  Future<Result<List<PublicFolderWall>>> fetchWallIds(String folderId) async => Result.success(<PublicFolderWall>[]);
}

PrismFavouriteWall _wall(String id) => PrismFavouriteWall(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://x/$id.jpg',
      thumbnailUrl: 'https://x/$id-t.jpg',
    ),
  ),
);

/// A folder owned by [ownerId] with one section `s1` (Dark).
FolderEntity _folder({String ownerId = 'u1', List<FolderMember> editors = const <FolderMember>[]}) => FolderEntity(
  id: 'a',
  ownerId: ownerId,
  name: 'F-a',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  itemCount: 2,
  covers: const <String>[],
  editors: editors,
  sections: const <FolderSection>[FolderSection(id: 's1', name: 'Dark')],
);

FoldersBloc _blocFor(_FakeOrganizeRepository repo) {
  final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
  addTearDown(bloc.close);
  return bloc;
}

Future<bool> _started(FoldersBloc bloc, {String userId = 'u1'}) =>
    bloc.run((id) => FoldersEvent.started(userId: userId, operationId: id));

Future<bool> _opened(FoldersBloc bloc, String folderId) =>
    bloc.run((id) => FoldersEvent.folderOpened(folderId: folderId, operationId: id));

Future<bool> _organize(FoldersBloc bloc, FolderEdit edit) =>
    bloc.run((id) => FoldersEvent.organizeRequested(folderId: 'a', edit: edit, operationId: id));

void main() {
  test('a failed item reload prevents section edits from using stale items', () async {
    final repo = _FakeOrganizeRepository()
      ..folders = <FolderEntity>[_folder()]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[_wall('a')],
      };
    final bloc = _blocFor(repo);
    await _started(bloc);
    await _opened(bloc, 'a');
    repo.failItems = true;

    expect(await _opened(bloc, 'a'), isFalse);
    expect(bloc.state.itemsStatus['a'], LoadStatus.failure);
    expect(await _organize(bloc, const SectionAdded(id: 's2', name: 'Light')), isFalse);
    expect(repo.organizeCalls, isEmpty);
  });

  test('owner adds a section and it is written with no moves', () async {
    final repo = _FakeOrganizeRepository()
      ..folders = <FolderEntity>[_folder().copyWith(sections: const <FolderSection>[])];
    final bloc = _blocFor(repo);
    await _started(bloc);
    await _opened(bloc, 'a');

    final bool ok = await _organize(bloc, const SectionAdded(id: 's1', name: 'Dark'));

    expect(ok, isTrue);
    expect(repo.organizeCalls, hasLength(1));
    expect(repo.organizeCalls.single.sections, <FolderSection>[const FolderSection(id: 's1', name: 'Dark')]);
    expect(repo.organizeCalls.single.moves, <String, String?>{});
    expect(bloc.state.folder('a')!.sections, <FolderSection>[const FolderSection(id: 's1', name: 'Dark')]);
  });

  test('editor moves two walls into a section', () async {
    final repo = _FakeOrganizeRepository()
      ..folders = <FolderEntity>[
        _folder(
          ownerId: 'owner',
          editors: <FolderMember>[
            FolderMember(uid: 'u1', role: FolderRole.editor, addedBy: 'owner', addedAt: DateTime.utc(2026)),
          ],
        ),
      ]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[_wall('a'), _wall('b')],
      };
    final bloc = _blocFor(repo);
    await _started(bloc);
    await _opened(bloc, 'a');

    final bool ok = await _organize(
      bloc,
      const WallsMoved(itemKeys: <String>['prism_a', 'prism_b'], sectionId: 's1', method: WallMoveMethod.menu),
    );

    expect(ok, isTrue);
    expect(repo.organizeCalls.single.moves, <String, String?>{'prism_a': 's1', 'prism_b': 's1'});
    expect(bloc.state.itemSections['a'], <String, String>{'prism_a': 's1', 'prism_b': 's1'});
  });

  test('moving a wall back to Unsorted writes a null move and drops its section', () async {
    final repo = _FakeOrganizeRepository()
      ..folders = <FolderEntity>[_folder()]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[_wall('a'), _wall('b')],
      }
      ..sectionOfWall = <String, String>{'prism_a': 's1'};
    final bloc = _blocFor(repo);
    await _started(bloc);
    await _opened(bloc, 'a');

    final bool ok = await _organize(
      bloc,
      const WallsMoved(itemKeys: <String>['prism_a'], sectionId: null, method: WallMoveMethod.menu),
    );

    expect(ok, isTrue);
    expect(repo.organizeCalls.single.moves, <String, String?>{'prism_a': null});
    expect(bloc.state.itemSections['a']!.containsKey('prism_a'), isFalse);
  });

  test('a user who is neither owner nor editor is refused and nothing is written', () async {
    final repo = _FakeOrganizeRepository()
      ..folders = <FolderEntity>[_folder()]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[_wall('a')],
      };
    // The folder reaches the state even though u2 has no role in it, so the handler's own role check is what refuses.
    repo.fetchFoldersOverride = (userId) async => Result.success(<FolderEntity>[_folder()]);
    final bloc = _blocFor(repo);
    await _started(bloc, userId: 'u2');
    await _opened(bloc, 'a');

    final bool ok = await _organize(bloc, const SectionAdded(id: 's2', name: 'Light'));

    expect(ok, isFalse);
    expect(repo.organizeCalls, isEmpty);
  });

  test('an invalid edit is refused and nothing is written', () async {
    final repo = _FakeOrganizeRepository()..folders = <FolderEntity>[_folder()];
    final bloc = _blocFor(repo);
    await _started(bloc);
    await _opened(bloc, 'a');

    final bool ok = await _organize(bloc, const SectionRenamed(id: 'nope', name: 'Light'));

    expect(ok, isFalse);
    expect(repo.organizeCalls, isEmpty);
  });

  test('a repository failure returns false and leaves the sections unchanged', () async {
    final repo = _FakeOrganizeRepository()
      ..folders = <FolderEntity>[_folder().copyWith(sections: const <FolderSection>[])]
      ..organizeResult = Result.error<void>(const ServerFailure('boom'));
    final bloc = _blocFor(repo);
    await _started(bloc);
    await _opened(bloc, 'a');

    final bool ok = await _organize(bloc, const SectionAdded(id: 's1', name: 'Dark'));

    expect(ok, isFalse);
    expect(repo.organizeCalls, hasLength(1));
    expect(bloc.state.folder('a')!.sections, isEmpty);
  });

  test('moving a wall to the section it is already in is a no-op', () async {
    final repo = _FakeOrganizeRepository()
      ..folders = <FolderEntity>[_folder()]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[_wall('a')],
      }
      ..sectionOfWall = <String, String>{'prism_a': 's1'};
    final bloc = _blocFor(repo);
    await _started(bloc);
    await _opened(bloc, 'a');

    final bool ok = await _organize(
      bloc,
      const WallsMoved(itemKeys: <String>['prism_a'], sectionId: 's1', method: WallMoveMethod.drag),
    );

    expect(ok, isTrue);
    expect(repo.organizeCalls, isEmpty);
  });

  test('opening a folder fills itemSections from the item section ids only', () async {
    final repo = _FakeOrganizeRepository()
      ..folders = <FolderEntity>[_folder()]
      ..items = <String, List<FavouriteWallEntity>>{
        'a': <FavouriteWallEntity>[_wall('a'), _wall('b')],
      }
      ..sectionOfWall = <String, String>{'prism_a': 's1'};
    final bloc = _blocFor(repo);
    await _started(bloc);

    expect(await _opened(bloc, 'a'), isTrue);

    expect(bloc.state.itemSections['a'], <String, String>{'prism_a': 's1'});
    expect(bloc.state.itemSections['a']!.containsKey('prism_b'), isFalse);
  });
}
