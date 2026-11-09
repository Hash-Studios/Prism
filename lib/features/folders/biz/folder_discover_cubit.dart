import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/folders/data/wall_traits_source.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

enum FolderDiscoverStatus { loading, ready, failed }

/// Reads the moods and categories of the given saves. The app reads them from `walls`.
typedef SaveTraitsLoader = Future<List<WallTraits>> Function(List<FavouriteWallEntity> saves);

class FolderDiscoverState {
  const FolderDiscoverState({
    this.status = FolderDiscoverStatus.loading,
    this.lists = FolderDiscoverLists.empty,
    this.followed = const <String>{},
    this.busy = const <String>{},
    this.likeYourSaves,
    this.likeYourSavesFailed = false,
  });

  final FolderDiscoverStatus status;

  /// The server lists, without the viewer's own folders, blocked creators and folders the viewer reported.
  final FolderDiscoverLists lists;
  final Set<String> followed;

  /// Folders with a follow change on its way to the server.
  final Set<String> busy;

  /// Null until ranked. Empty when the viewer has no saves that match.
  final List<DiscoverFolder>? likeYourSaves;
  final bool likeYourSavesFailed;

  FolderDiscoverState copyWith({
    FolderDiscoverStatus? status,
    FolderDiscoverLists? lists,
    Set<String>? followed,
    Set<String>? busy,
    List<DiscoverFolder>? Function()? likeYourSaves,
    bool? likeYourSavesFailed,
  }) => FolderDiscoverState(
    status: status ?? this.status,
    lists: lists ?? this.lists,
    followed: followed ?? this.followed,
    busy: busy ?? this.busy,
    likeYourSaves: likeYourSaves == null ? this.likeYourSaves : likeYourSaves(),
    likeYourSavesFailed: likeYourSavesFailed ?? this.likeYourSavesFailed,
  );
}

/// The Folders row in Search and the discover page: trending, new, and "Like your saves" ranked on the device.
@injectable
class FolderDiscoverCubit extends Cubit<FolderDiscoverState> {
  FolderDiscoverCubit(
    this._folders,
    this._favourites,
    UserBlockRepository blocks,
    FirestoreClient firestore, {
    @ignoreParam SaveTraitsLoader? saveTraits,
  }) : _saveTraits = saveTraits ?? _wallTraits(WallTraitsSource(firestore)),
       _blocks = blocks,
       super(const FolderDiscoverState()) {
    _blockChanges = blocks.watchBlockedCreators().listen((_) => _show());
  }

  /// The newest saves that "Like your saves" reads.
  static const int savesRead = 30;

  final PublicFoldersRepository _folders;
  final FavouriteWallsRepository _favourites;
  final UserBlockRepository _blocks;
  final SaveTraitsLoader _saveTraits;
  late final StreamSubscription<BlockedCreators> _blockChanges;
  FolderDiscoverLists _all = FolderDiscoverLists.empty;
  final Set<String> _reported = <String>{};
  List<WallTraits>? _traits;
  int _load = 0;
  String? _viewerId;

  /// The traits of each save that still has a public wall, in the order of [saves].
  static SaveTraitsLoader _wallTraits(WallTraitsSource source) => (saves) async {
    final Map<String, WallTraits> byKey = await source.traitsOf(saves);
    return <WallTraits>[
      for (final FavouriteWallEntity save in saves)
        if (byKey[folderItemKey(save)] case final WallTraits traits) traits,
    ];
  };

  @override
  Future<void> close() async {
    await _blockChanges.cancel();
    return super.close();
  }

  /// Signed-out guests cannot read the lists, so they get empty lists.
  Future<void> load() async {
    final int load = ++_load;
    if (!app_state.prismUser.loggedIn) {
      _resetForViewer(null);
      return emit(const FolderDiscoverState(status: FolderDiscoverStatus.ready));
    }
    final String viewer = app_state.prismUser.id;
    if (_viewerId != viewer) {
      _resetForViewer(viewer);
      emit(const FolderDiscoverState());
    }
    if (state.status != FolderDiscoverStatus.ready) emit(state.copyWith(status: FolderDiscoverStatus.loading));
    final (Result<FolderDiscoverLists> lists, Result<Set<String>> followed, BlockedCreators _) = await (
      _folders.fetchDiscover(),
      _folders.fetchFollowedIds(viewer),
      _blocks.loadBlockedCreators(),
    ).wait;
    if (isClosed || load != _load || app_state.prismUser.id != viewer) return;
    if (lists.isFailure) {
      if (state.status != FolderDiscoverStatus.ready) emit(state.copyWith(status: FolderDiscoverStatus.failed));
      return;
    }
    _all = lists.data!;
    emit(state.copyWith(status: FolderDiscoverStatus.ready, followed: followed.data ?? state.followed));
    _show();
  }

  /// Ranks "Like your saves" from the viewer's newest saves. It reads the saves once per page.
  Future<void> loadLikeYourSaves() async {
    if (!app_state.prismUser.loggedIn) return emit(state.copyWith(likeYourSaves: () => const <DiscoverFolder>[]));
    final String viewer = app_state.prismUser.id;
    if (_traits != null) return _show();
    emit(state.copyWith(likeYourSaves: () => null, likeYourSavesFailed: false));
    try {
      final Result<List<FavouriteWallEntity>> saves = await _favourites.fetchFavourites(userId: viewer);
      if (saves.isFailure) throw saves.failure ?? StateError('favourites');
      final List<FavouriteWallEntity> newest = saves.data!.whereType<PrismFavouriteWall>().toList()
        ..sort((a, b) => (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)));
      final List<WallTraits> traits = await _saveTraits(newest.take(savesRead).toList(growable: false));
      if (!isClosed && app_state.prismUser.loggedIn && app_state.prismUser.id == viewer && _viewerId == viewer) {
        _traits = traits;
        _show();
      }
    } catch (error, stackTrace) {
      logger.w('[FolderDiscover] saves failed', error: error, stackTrace: stackTrace);
      if (!isClosed && app_state.prismUser.loggedIn && app_state.prismUser.id == viewer && _viewerId == viewer) {
        emit(state.copyWith(likeYourSavesFailed: true));
      }
    }
  }

  /// Follows or unfollows at once, and undoes the change if the server refuses. Returns the failure, or null.
  Future<PublicFolderFailure?> toggleFollow(DiscoverFolder folder) async {
    if (state.busy.contains(folder.id)) return null;
    final String viewer = app_state.prismUser.id;
    final bool next = !state.followed.contains(folder.id);
    Set<String> withFollow(bool on) =>
        on ? <String>{...state.followed, folder.id} : (state.followed.toSet()..remove(folder.id));
    emit(state.copyWith(followed: withFollow(next), busy: <String>{...state.busy, folder.id}));
    final Result<void> result = await _folders.setFollowing(folder.id, following: next);
    if (isClosed || !app_state.prismUser.loggedIn || app_state.prismUser.id != viewer || _viewerId != viewer) {
      return null;
    }
    final Set<String> busy = state.busy.toSet()..remove(folder.id);
    if (result.isFailure) {
      emit(state.copyWith(followed: withFollow(!next), busy: busy));
      final Object? failure = result.failure;
      return failure is PublicFolderFailure ? failure : PublicFolderFailure('$failure');
    }
    emit(state.copyWith(busy: busy));
    return null;
  }

  /// A folder the viewer reported leaves their lists at once.
  void hideReported(String folderId) {
    _reported.add(folderId);
    _show();
  }

  void _show() {
    if (isClosed) return;
    if (!app_state.prismUser.loggedIn || _viewerId != app_state.prismUser.id) {
      emit(state.copyWith(lists: FolderDiscoverLists.empty, likeYourSaves: () => const <DiscoverFolder>[]));
      return;
    }
    final FolderDiscoverLists visible = _all.visibleTo(app_state.prismUser.id, _blocks.blockedCreators);
    bool kept(DiscoverFolder f) => !_reported.contains(f.id);
    final FolderDiscoverLists lists = FolderDiscoverLists(
      trending: visible.trending.where(kept).toList(growable: false),
      fresh: visible.fresh.where(kept).toList(growable: false),
    );
    final List<WallTraits>? traits = _traits;
    emit(
      state.copyWith(
        lists: lists,
        likeYourSaves: traits == null ? null : () => rankLikeYourSaves(lists.candidates, traits),
      ),
    );
  }

  void _resetForViewer(String? viewer) {
    _viewerId = viewer;
    _all = FolderDiscoverLists.empty;
    _reported.clear();
    _traits = null;
  }
}
