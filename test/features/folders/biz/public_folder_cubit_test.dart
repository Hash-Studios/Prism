import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/folders/biz/public_folder_cubit.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePublicFolders extends Fake implements PublicFoldersRepository {
  Result<PublicFolderEntity?> folder = Result.success(_folder(0));
  Result<List<String>> wallIds = Result.success(<String>[]);
  Result<bool> following = Result.success(false);
  Future<Result<void>> Function()? onSetFollowing;
  final List<({String id, bool following})> followCalls = <({String id, bool following})>[];

  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => folder;

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async => wallIds;

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) async => following;

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async {
    followCalls.add((id: folderId, following: following));
    return await onSetFollowing?.call() ?? Result.success<void>(null);
  }
}

class _FakeMoodRepository extends Fake implements MoodRepository {
  final List<String> requestedIds = <String>[];
  bool? requestedKeepOrder;

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async {
    requestedIds.addAll(ids);
    requestedKeepOrder = keepOrder;
    return ids.map(_wall).toList();
  }
}

PublicFolderEntity _folder(int followerCount) => PublicFolderEntity(
  id: 'f1',
  ownerId: 'o1',
  name: 'Name',
  itemCount: 2,
  covers: const <String>[],
  followerCount: followerCount,
);

PrismWallpaper _wall(String id) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: 'https://x/$id.jpg',
    thumbnailUrl: 'https://x/$id-t.jpg',
  ),
);

void main() {
  late _FakePublicFolders repo;
  late _FakeMoodRepository walls;

  PublicFolderCubit cubitFor({int followerCount = 3, bool following = false}) {
    repo
      ..folder = Result.success(_folder(followerCount))
      ..following = Result.success(following)
      ..wallIds = Result.success(<String>['w2', 'w1']);
    return PublicFolderCubit(repo, walls);
  }

  setUp(() {
    repo = _FakePublicFolders();
    walls = _FakeMoodRepository();
  });

  test('load shows the walls in folder order and the viewer follow state', () async {
    final PublicFolderCubit cubit = cubitFor(following: true);
    addTearDown(cubit.close);

    await cubit.load('f1', viewerId: 'u1');

    expect(cubit.state.status, PublicFolderStatus.ready);
    expect(cubit.state.walls.map((wall) => wall.core.id).toList(), <String>['w2', 'w1']);
    expect(cubit.state.following, isTrue);
    expect(walls.requestedIds, <String>['w2', 'w1']);
    expect(walls.requestedKeepOrder, isTrue);
  });

  test('load is unavailable when the folder read returns null', () async {
    repo.folder = Result.success(null);
    final PublicFolderCubit cubit = PublicFolderCubit(repo, walls);
    addTearDown(cubit.close);

    await cubit.load('f1', viewerId: 'u1');

    expect(cubit.state.status, PublicFolderStatus.unavailable);
    expect(cubit.state.folder, isNull);
  });

  test('load fails when the folder read errors', () async {
    repo.folder = Result.error(const ServerFailure('boom'));
    final PublicFolderCubit cubit = PublicFolderCubit(repo, walls);
    addTearDown(cubit.close);

    await cubit.load('f1', viewerId: 'u1');

    expect(cubit.state.status, PublicFolderStatus.failure);
  });

  test('toggleFollow on a folder not followed follows it at once and saves the change', () async {
    final PublicFolderCubit cubit = cubitFor();
    addTearDown(cubit.close);
    await cubit.load('f1', viewerId: 'u1');
    final List<PublicFolderState> emitted = <PublicFolderState>[];
    final StreamSubscription<PublicFolderState> sub = cubit.stream.listen(emitted.add);
    addTearDown(sub.cancel);

    final Future<PublicFolderFailure?> pending = cubit.toggleFollow();

    expect(cubit.state.following, isTrue);
    expect(cubit.state.followBusy, isTrue);
    expect(cubit.state.folder!.followerCount, 4);
    expect(await pending, isNull);
    await pumpEventQueue();
    expect(emitted.first.following, isTrue);
    expect(emitted.first.folder!.followerCount, 4);
    expect(emitted.first.followBusy, isTrue);
    expect(emitted.last.followBusy, isFalse);
    expect(repo.followCalls, <({String id, bool following})>[(id: 'f1', following: true)]);
    expect(cubit.state.followBusy, isFalse);
  });

  test('toggleFollow on a followed folder unfollows it and lowers the count', () async {
    final PublicFolderCubit cubit = cubitFor(following: true);
    addTearDown(cubit.close);
    await cubit.load('f1', viewerId: 'u1');

    expect(await cubit.toggleFollow(), isNull);
    expect(cubit.state.following, isFalse);
    expect(cubit.state.folder!.followerCount, 2);
    expect(cubit.state.followBusy, isFalse);
    expect(repo.followCalls.last, (id: 'f1', following: false));
  });

  test('toggleFollow never takes the follower count below zero', () async {
    final PublicFolderCubit cubit = cubitFor(followerCount: 0, following: true);
    addTearDown(cubit.close);
    await cubit.load('f1', viewerId: 'u1');

    expect(await cubit.toggleFollow(), isNull);
    expect(cubit.state.following, isFalse);
    expect(cubit.state.folder!.followerCount, 0);
  });

  test('a refused toggleFollow restores the old follow state and count and returns the refusal', () async {
    final PublicFolderCubit cubit = cubitFor(followerCount: 5, following: true);
    addTearDown(cubit.close);
    await cubit.load('f1', viewerId: 'u1');
    repo.onSetFollowing = () async =>
        Result.error<void>(const PublicFolderFailure('x', refusal: PublicFolderRefusal.unavailable));

    final PublicFolderFailure? refusal = await cubit.toggleFollow();

    expect(refusal, isA<PublicFolderFailure>());
    expect(refusal!.refusal, PublicFolderRefusal.unavailable);
    expect(cubit.state.following, isTrue);
    expect(cubit.state.folder!.followerCount, 5);
    expect(cubit.state.followBusy, isFalse);
  });

  test('a second toggleFollow while the first is in flight does nothing', () async {
    final PublicFolderCubit cubit = cubitFor();
    addTearDown(cubit.close);
    await cubit.load('f1', viewerId: 'u1');
    final Completer<Result<void>> gate = Completer<Result<void>>();
    repo.onSetFollowing = () => gate.future;

    final Future<PublicFolderFailure?> first = cubit.toggleFollow();
    expect(await cubit.toggleFollow(), isNull);
    expect(repo.followCalls, hasLength(1));
    expect(cubit.state.folder!.followerCount, 4);

    gate.complete(Result.success<void>(null));
    expect(await first, isNull);
    expect(cubit.state.followBusy, isFalse);
    expect(cubit.state.following, isTrue);
  });
}
