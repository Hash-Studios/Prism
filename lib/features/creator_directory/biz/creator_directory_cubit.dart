import 'dart:async';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

enum CreatorDirectoryStatus { loading, loaded, failed }

class CreatorDirectoryState {
  const CreatorDirectoryState({
    this.status = CreatorDirectoryStatus.loading,
    this.creators = const <DirectoryCreator>[],
    this.followed = const <String>{},
    this.categories = const <String>[],
    this.category,
    this.nextRank,
    this.loadingMore = false,
  });

  final CreatorDirectoryStatus status;
  final List<DirectoryCreator> creators;

  /// Creators the viewer followed when they loaded. Follows made here live in the follow bloc.
  final Set<String> followed;

  /// Filter chips: the main categories of the top creators, most common first.
  final List<String> categories;
  final String? category;
  final int? nextRank;
  final bool loadingMore;

  bool get isEmpty => status == CreatorDirectoryStatus.loaded && creators.isEmpty;
  bool get hasMore => nextRank != null;

  CreatorDirectoryState copyWith({
    CreatorDirectoryStatus? status,
    List<DirectoryCreator>? creators,
    Set<String>? followed,
    List<String>? categories,
    String? Function()? category,
    int? Function()? nextRank,
    bool? loadingMore,
  }) => CreatorDirectoryState(
    status: status ?? this.status,
    creators: creators ?? this.creators,
    followed: followed ?? this.followed,
    categories: categories ?? this.categories,
    category: category == null ? this.category : category(),
    nextRank: nextRank == null ? this.nextRank : nextRank(),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The Creators row and the See all page. The row shows only creators the viewer does not follow yet.
@injectable
class CreatorDirectoryCubit extends Cubit<CreatorDirectoryState> {
  CreatorDirectoryCubit(this._repository, UserBlockRepository blocks) : super(const CreatorDirectoryState()) {
    _blocks = blocks.watchBlockedCreators().listen(_hideBlocked);
  }

  static const int rowSize = 10;
  static const int _maxChips = 8;

  final CreatorDirectoryRepository _repository;
  late final StreamSubscription<BlockedCreators> _blocks;
  int _load = 0;

  /// The loaded creators before later block changes, so a creator hidden while the block list was unknown comes back.
  List<DirectoryCreator> _all = const <DirectoryCreator>[];

  /// Shows a fixed list, for the More like sheet. Blocks still remove creators from it.
  void show(List<DirectoryCreator> creators) =>
      emit(CreatorDirectoryState(status: CreatorDirectoryStatus.loaded, creators: creators));

  /// A creator the viewer blocks leaves the list at once, without a reload. Filtering [_all], not the shown list,
  /// brings back creators that an unknown block list hid.
  void _hideBlocked(BlockedCreators blocked) {
    if (isClosed) return;
    final List<DirectoryCreator> visible = _all
        .where((c) => !BlockedCreatorsFilter.hidesCreatorUid(c.uid, blocked))
        .toList(growable: false);
    if (!listEquals(visible, state.creators)) super.emit(state.copyWith(creators: visible));
  }

  /// Loads are already filtered by the repository. A status-only change passes the shown list back, so [_all] stays.
  @override
  void emit(CreatorDirectoryState next) {
    if (!identical(next.creators, state.creators)) _all = next.creators;
    super.emit(next);
  }

  @override
  Future<void> close() async {
    await _blocks.cancel();
    return super.close();
  }

  /// The signed-in user's id, or empty for a guest. Guests can read the directory.
  static String get _viewer => app_state.prismUser.loggedIn ? app_state.prismUser.id : '';

  /// Loads the Home or search row.
  Future<void> loadRow() async {
    final int load = ++_load;
    final String viewer = _viewer;
    try {
      final CreatorPage page = await _repository.fetchPage(limit: rowSize);
      final Set<String> followed = await _repository.followedAmong(_uids(page.creators));
      if (isClosed || load != _load) return;
      if (_viewer != viewer) {
        emit(const CreatorDirectoryState(status: CreatorDirectoryStatus.loaded));
        return;
      }
      emit(
        CreatorDirectoryState(
          status: CreatorDirectoryStatus.loaded,
          creators: page.creators.where((c) => !followed.contains(c.uid)).toList(growable: false),
        ),
      );
    } catch (error) {
      logger.w('[CreatorDirectory] row load failed', error: error);
      if (!isClosed && load == _load) emit(state.copyWith(status: CreatorDirectoryStatus.failed));
    }
  }

  /// Loads the first page of See all, filtered to [category] when set.
  Future<void> loadPage({String? category}) async {
    final int load = ++_load;
    final String viewer = _viewer;
    emit(state.copyWith(status: CreatorDirectoryStatus.loading, category: () => category, loadingMore: false));
    try {
      final CreatorPage page = await _repository.fetchPage(category: category);
      final Set<String> followed = await _repository.followedAmong(_uids(page.creators));
      if (isClosed || load != _load) return;
      if (_viewer != viewer) {
        emit(const CreatorDirectoryState(status: CreatorDirectoryStatus.loaded));
        return;
      }
      emit(
        state.copyWith(
          status: CreatorDirectoryStatus.loaded,
          creators: page.creators,
          followed: followed,
          categories: state.categories.isEmpty && category == null ? _chips(page.creators) : null,
          nextRank: () => page.nextRank,
        ),
      );
    } catch (error) {
      logger.w('[CreatorDirectory] page load failed', error: error);
      if (!isClosed && load == _load) emit(state.copyWith(status: CreatorDirectoryStatus.failed));
    }
  }

  Future<void> loadMore() async {
    final String viewer = _viewer;
    final int? after = state.nextRank;
    if (after == null || state.loadingMore || state.status != CreatorDirectoryStatus.loaded) return;
    final int load = _load;
    emit(state.copyWith(loadingMore: true));
    try {
      final CreatorPage page = await _repository.fetchPage(category: state.category, afterRank: after);
      final Set<String> followed = await _repository.followedAmong(_uids(page.creators));
      if (isClosed || load != _load) return;
      if (_viewer != viewer) {
        emit(const CreatorDirectoryState(status: CreatorDirectoryStatus.loaded));
        return;
      }
      final Set<String> seen = _uids(state.creators).toSet();
      emit(
        state.copyWith(
          creators: <DirectoryCreator>[...state.creators, ...page.creators.where((c) => !seen.contains(c.uid))],
          followed: <String>{...state.followed, ...followed},
          nextRank: () => page.nextRank,
          loadingMore: false,
        ),
      );
    } catch (error) {
      logger.w('[CreatorDirectory] next page failed', error: error);
      if (!isClosed && load == _load) emit(state.copyWith(loadingMore: false));
    }
  }

  static List<String> _uids(List<DirectoryCreator> creators) => creators.map((c) => c.uid).toList(growable: false);

  static List<String> _chips(List<DirectoryCreator> creators) {
    final Map<String, int> counts = <String, int>{};
    for (final DirectoryCreator c in creators) {
      for (final String category in c.entry.categories) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    final List<MapEntry<String, int>> sorted = counts.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    return sorted.take(_maxChips).map((e) => e.key).toList(growable: false);
  }
}
