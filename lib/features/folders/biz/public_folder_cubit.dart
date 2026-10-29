import 'dart:async';

import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

enum PublicFolderStatus {
  loading,
  ready,

  /// Private, deleted, hidden by a moderator, or hidden by a block in either direction.
  unavailable,
  failure,
}

class PublicFolderState {
  const PublicFolderState({
    this.status = PublicFolderStatus.loading,
    this.folder,
    this.walls = const <PrismWallpaper>[],
    this.following = false,
    this.followBusy = false,
  });

  final PublicFolderStatus status;
  final PublicFolderEntity? folder;
  final List<PrismWallpaper> walls;
  final bool following;
  final bool followBusy;

  PublicFolderState copyWith({
    PublicFolderStatus? status,
    PublicFolderEntity? folder,
    List<PrismWallpaper>? walls,
    bool? following,
    bool? followBusy,
  }) => PublicFolderState(
    status: status ?? this.status,
    folder: folder ?? this.folder,
    walls: walls ?? this.walls,
    following: following ?? this.following,
    followBusy: followBusy ?? this.followBusy,
  );
}

/// A public folder seen by someone other than its owner: its walls, its header and the viewer's follow.
@injectable
class PublicFolderCubit extends Cubit<PublicFolderState> {
  PublicFolderCubit(this._repository, this._walls) : super(const PublicFolderState()) {
    _visibility = _walls.watchVisibilityChanges().listen((_) {
      final request = _request;
      if (request != null) unawaited(load(request.folderId, viewerId: request.viewerId));
    });
  }

  final PublicFoldersRepository _repository;
  final MoodRepository _walls;
  late final StreamSubscription<void> _visibility;
  ({String folderId, String viewerId})? _request;
  int _loadVersion = 0;

  @override
  Future<void> close() async {
    ++_loadVersion;
    _request = null;
    await _visibility.cancel();
    return super.close();
  }

  /// A [quiet] load keeps the shown folder until the new one arrives and on read errors.
  Future<void> load(String folderId, {required String viewerId, bool quiet = false}) async {
    if (isClosed) return;
    final ({String folderId, String viewerId})? loaded = _request;
    final bool keep =
        quiet &&
        state.status == PublicFolderStatus.ready &&
        loaded?.folderId == folderId &&
        loaded?.viewerId == viewerId;
    if (keep && state.followBusy) return;
    _request = (folderId: folderId, viewerId: viewerId);
    final int version = ++_loadVersion;
    bool current() => !isClosed && version == _loadVersion;
    if (!keep) emit(const PublicFolderState());
    final Result<PublicFolderEntity?> folder = await _repository.fetchFolder(folderId);
    if (!current() || (keep && folder.isFailure)) return;
    if (folder.isFailure) return emit(const PublicFolderState(status: PublicFolderStatus.failure));
    final PublicFolderEntity? found = folder.data;
    if (found == null) return emit(const PublicFolderState(status: PublicFolderStatus.unavailable));
    final (Result<List<String>> ids, Result<bool> following) = await (
      _repository.fetchWallIds(folderId),
      viewerId.isEmpty
          ? Future<Result<bool>>.value(Result.success(false))
          : _repository.isFollowing(folderId, viewerId),
    ).wait;
    if (!current()) return;
    if (ids.isFailure) {
      final Object? failure = ids.failure;
      final bool unavailable = failure is PublicFolderFailure && failure.refusal == PublicFolderRefusal.unavailable;
      if (keep && !unavailable) return;
      return emit(PublicFolderState(status: unavailable ? PublicFolderStatus.unavailable : PublicFolderStatus.failure));
    }
    try {
      final List<PrismWallpaper> walls = await _walls.fetchMoodWalls(ids.data!, keepOrder: true);
      if (!current()) return;
      emit(
        PublicFolderState(
          status: PublicFolderStatus.ready,
          folder: found,
          walls: walls,
          following: following.data ?? false,
        ),
      );
    } catch (error, stackTrace) {
      logger.w('[PublicFolderCubit] walls failed', error: error, stackTrace: stackTrace);
      if (keep) return;
      if (current()) emit(PublicFolderState(status: PublicFolderStatus.failure, folder: found));
    }
  }

  /// Follows or unfollows at once, and undoes the change when the server refuses it. Returns the refusal.
  Future<PublicFolderFailure?> toggleFollow() async {
    final PublicFolderEntity? folder = state.folder;
    if (folder == null || state.followBusy || state.status != PublicFolderStatus.ready) return null;
    final int version = ++_loadVersion;
    bool current() => !isClosed && version == _loadVersion;
    final bool next = !state.following;
    final int count = folder.followerCount;
    emit(
      state.copyWith(
        following: next,
        followBusy: true,
        folder: folder.copyWith(followerCount: next ? count + 1 : (count - 1).clamp(0, count)),
      ),
    );
    final Result<void> result = await _repository.setFollowing(folder.id, following: next);
    if (!current()) return null;
    if (result.isSuccess) {
      emit(state.copyWith(followBusy: false));
      return null;
    }
    final Object? failure = result.failure;
    if (failure is PublicFolderFailure && failure.refusal == PublicFolderRefusal.unavailable) {
      emit(const PublicFolderState(status: PublicFolderStatus.unavailable));
    } else {
      emit(state.copyWith(following: !next, followBusy: false, folder: folder));
    }
    return failure is PublicFolderFailure ? failure : PublicFolderFailure(failure.toString());
  }
}
