import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/folders/biz/folder_discover_cubit.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_user_block_repository.dart';

class _FakePublicFolders extends Fake implements PublicFoldersRepository {
  Result<FolderDiscoverLists> discover = Result.success(FolderDiscoverLists.empty);
  Result<Set<String>> followed = Result.success(<String>{});
  Result<void> followResult = Result.success<void>(null);
  Future<Result<void>> Function(String folderId, bool following)? followHandler;
  final List<({String id, bool following})> followCalls = <({String id, bool following})>[];
  int discoverCalls = 0;

  @override
  Future<Result<FolderDiscoverLists>> fetchDiscover() async {
    discoverCalls++;
    return discover;
  }

  @override
  Future<Result<Set<String>>> fetchFollowedIds(String userId) async => followed;

  @override
  Future<void> recordSignal(String folderId, FolderSignal signal) async {}

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async {
    followCalls.add((id: folderId, following: following));
    if (followHandler case final Future<Result<void>> Function(String, bool) handler) {
      return handler(folderId, following);
    }
    return followResult;
  }
}

class _FakeFavourites extends Fake implements FavouriteWallsRepository {
  Result<List<FavouriteWallEntity>> saves = Result.success(<FavouriteWallEntity>[]);
  Future<Result<List<FavouriteWallEntity>>> Function(String userId)? fetchHandler;
  int fetchCalls = 0;

  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async {
    fetchCalls++;
    if (fetchHandler case final Future<Result<List<FavouriteWallEntity>>> Function(String) handler) {
      return handler(userId);
    }
    return saves;
  }
}

class _FakeFirestore extends Fake implements FirestoreClient {}

DiscoverFolder _folder(String id, {String owner = 'owner', List<String> moods = const <String>[]}) =>
    DiscoverFolder(id: id, ownerId: owner, name: 'Folder $id', itemCount: 10, moods: moods);

PrismFavouriteWall _save(String id, DateTime addedAt) => PrismFavouriteWall(
  id: id,
  favouritedAt: addedAt,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  ),
);

List<String> _ids(List<DiscoverFolder>? folders) => folders!.map((f) => f.id).toList();

void main() {
  late _FakePublicFolders folders;
  late _FakeFavourites favourites;
  late FakeUserBlockRepository blocks;

  FolderDiscoverCubit cubitWith({SaveTraitsLoader? saveTraits}) =>
      FolderDiscoverCubit(folders, favourites, blocks, _FakeFirestore(), saveTraits: saveTraits);

  setUp(() {
    folders = _FakePublicFolders();
    favourites = _FakeFavourites();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'me'
      ..loggedIn = true;
  });

  tearDown(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  test('load for a signed-in user emits ready with the lists and the followed ids', () async {
    folders
      ..discover = Result.success(
        FolderDiscoverLists(
          trending: <DiscoverFolder>[_folder('t1', owner: 'a')],
          fresh: <DiscoverFolder>[_folder('n1', owner: 'b')],
        ),
      )
      ..followed = Result.success(<String>{'t1'});
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, FolderDiscoverStatus.ready);
    expect(_ids(cubit.state.lists.trending), <String>['t1']);
    expect(_ids(cubit.state.lists.fresh), <String>['n1']);
    expect(cubit.state.followed, <String>{'t1'});
  });

  test('a guest sees the public lists and follows nothing', () async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    folders
      ..discover = Result.success(FolderDiscoverLists(trending: <DiscoverFolder>[_folder('t1', owner: 'a')]))
      ..followed = Result.success(<String>{'t1'});
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, FolderDiscoverStatus.ready);
    expect(_ids(cubit.state.lists.trending), <String>['t1']);
    expect(folders.discoverCalls, 1);
    // A guest has no follows, so the cubit does not read them.
    expect(cubit.state.followed, isEmpty);
  });

  test('a guest after sign-out keeps the public lists but not the follows of the last account', () async {
    folders
      ..discover = Result.success(FolderDiscoverLists(trending: <DiscoverFolder>[_folder('t1', owner: 'a')]))
      ..followed = Result.success(<String>{'t1'});
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.followed, <String>{'t1'});
    app_state.prismUser = app_constants.createGuestPrismUser();
    await cubit.load();
    blocks.completeInitial(<String>{});
    await Future<void>.delayed(Duration.zero);

    expect(_ids(cubit.state.lists.trending), <String>['t1']);
    expect(cubit.state.followed, isEmpty);
  });

  test('a guest who signs in to follow first loads the follows of the new account', () async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    folders
      ..discover = Result.success(FolderDiscoverLists(trending: <DiscoverFolder>[_folder('t1', owner: 'a')]))
      ..followed = Result.success(<String>{'t1'});
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);
    await cubit.load();

    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'me'
      ..loggedIn = true;
    await cubit.toggleFollow(_folder('t1'));

    // The new account already follows t1, so the tap unfollows it instead of a second follow.
    expect(folders.followCalls, <({String id, bool following})>[(id: 't1', following: false)]);
    expect(cubit.state.followed, isEmpty);
  });

  test('a fetchDiscover failure emits failed', () async {
    folders.discover = Result.error(const PublicFolderFailure('x'));
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, FolderDiscoverStatus.failed);
  });

  test('toggleFollow on success adds the id to followed', () async {
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);
    await cubit.load();

    final PublicFolderFailure? failure = await cubit.toggleFollow(_folder('t1'));

    expect(failure, isNull);
    expect(cubit.state.followed, contains('t1'));
    expect(cubit.state.busy, isNot(contains('t1')));
    expect(folders.followCalls, <({String id, bool following})>[(id: 't1', following: true)]);
  });

  test('toggleFollow on failure removes the id again and returns the failure', () async {
    folders.followResult = Result.error(const PublicFolderFailure('x'));
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);
    await cubit.load();

    final PublicFolderFailure? failure = await cubit.toggleFollow(_folder('t1'));

    expect(failure, isA<PublicFolderFailure>());
    expect(failure!.message, 'x');
    expect(cubit.state.followed, isNot(contains('t1')));
    expect(cubit.state.busy, isNot(contains('t1')));
  });

  test('a previous viewer follow refusal cannot roll back the new viewer state', () async {
    final Completer<Result<void>> oldRequest = Completer<Result<void>>();
    folders.followHandler = (_, _) => oldRequest.future;
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);
    await cubit.load();
    final Future<PublicFolderFailure?> oldFollow = cubit.toggleFollow(_folder('t1'));

    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'other'
      ..loggedIn = true;
    folders.followed = Result.success(<String>{'t1'});
    folders.followHandler = null;
    await cubit.load();
    oldRequest.complete(Result.error(const PublicFolderFailure('old viewer')));
    await oldFollow;

    expect(cubit.state.followed, contains('t1'));
    expect(cubit.state.busy, isEmpty);
  });

  test('hideReported removes the folder from both lists', () async {
    folders.discover = Result.success(
      FolderDiscoverLists(
        trending: <DiscoverFolder>[
          _folder('t1', owner: 'a'),
          _folder('t2', owner: 'b'),
        ],
        fresh: <DiscoverFolder>[
          _folder('t1', owner: 'a'),
          _folder('n1', owner: 'c'),
        ],
      ),
    );
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);
    await cubit.load();

    cubit.hideReported('t1');

    expect(_ids(cubit.state.lists.trending), <String>['t2']);
    expect(_ids(cubit.state.lists.fresh), <String>['n1']);
  });

  test('a block event removes that owner folders without a reload', () async {
    folders.discover = Result.success(
      FolderDiscoverLists(
        trending: <DiscoverFolder>[
          _folder('t1', owner: 'bad'),
          _folder('t2', owner: 'good'),
        ],
        fresh: <DiscoverFolder>[_folder('n1', owner: 'bad')],
      ),
    );
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);
    await cubit.load();
    final int callsBefore = folders.discoverCalls;

    blocks.completeInitial(<String>{'bad'});
    await Future<void>.delayed(Duration.zero);

    expect(_ids(cubit.state.lists.trending), <String>['t2']);
    expect(cubit.state.lists.fresh, isEmpty);
    expect(folders.discoverCalls, callsBefore);
  });

  test('loadLikeYourSaves ranks folders from the traits of the saves', () async {
    folders.discover = Result.success(
      FolderDiscoverLists(
        trending: <DiscoverFolder>[
          _folder('plain', owner: 'a'),
          _folder('dreamy', owner: 'b', moods: const <String>['dreamy']),
        ],
      ),
    );
    favourites.saves = Result.success(<FavouriteWallEntity>[
      _save('old', DateTime.utc(2026)),
      _save('new', DateTime.utc(2026, 2)),
    ]);
    final List<List<String>> loaded = <List<String>>[];
    final FolderDiscoverCubit cubit = cubitWith(
      saveTraits: (saves) async {
        loaded.add(saves.map((s) => s.id).toList());
        return <WallTraits>[
          const WallTraits(moods: <WallMood>[WallMood.dreamy]),
          const WallTraits(category: 'Nature'),
        ];
      },
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.loadLikeYourSaves();

    expect(loaded, <List<String>>[
      <String>['new', 'old'],
    ]);
    expect(_ids(cubit.state.likeYourSaves), <String>['dreamy']);
    expect(cubit.state.likeYourSavesFailed, isFalse);
  });

  test('a previous viewer saves failure does not update the new viewer state', () async {
    final Completer<Result<List<FavouriteWallEntity>>> oldRequest = Completer<Result<List<FavouriteWallEntity>>>();
    favourites.fetchHandler = (_) => oldRequest.future;
    final FolderDiscoverCubit cubit = cubitWith();
    addTearDown(cubit.close);
    await cubit.load();
    final Future<void> oldLoad = cubit.loadLikeYourSaves();

    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'other'
      ..loggedIn = true;
    favourites.fetchHandler = null;
    await cubit.load();
    oldRequest.complete(Result.error(const PublicFolderFailure('old viewer failed')));
    await oldLoad;

    expect(cubit.state.likeYourSavesFailed, isFalse);
  });

  test('a previous viewer saves success does not rank folders for the new viewer', () async {
    final Completer<List<WallTraits>> oldTraits = Completer<List<WallTraits>>();
    folders.discover = Result.success(
      FolderDiscoverLists(
        trending: <DiscoverFolder>[
          _folder('dreamy', moods: const <String>['dreamy']),
        ],
      ),
    );
    favourites.saves = Result.success(<FavouriteWallEntity>[]);
    final FolderDiscoverCubit cubit = cubitWith(saveTraits: (_) => oldTraits.future);
    addTearDown(cubit.close);
    await cubit.load();
    final Future<void> oldLoad = cubit.loadLikeYourSaves();

    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'other'
      ..loggedIn = true;
    await cubit.load();
    oldTraits.complete(<WallTraits>[
      const WallTraits(moods: <WallMood>[WallMood.dreamy]),
    ]);
    await oldLoad;

    expect(cubit.state.likeYourSaves, isNull);
  });
}
