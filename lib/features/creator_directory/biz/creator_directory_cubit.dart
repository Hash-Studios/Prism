import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:Prism/logger/logger.dart';
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
  CreatorDirectoryCubit(this._repository) : super(const CreatorDirectoryState());

  static const int rowSize = 10;
  static const int _maxChips = 8;

  final CreatorDirectoryRepository _repository;
  int _load = 0;

  /// Loads the Home or search row. Signed-out guests cannot read the directory, so the row stays empty for them.
  Future<void> loadRow() async {
    if (!app_state.prismUser.loggedIn) {
      emit(state.copyWith(status: CreatorDirectoryStatus.loaded, creators: const <DirectoryCreator>[]));
      return;
    }
    final int load = ++_load;
    try {
      final CreatorPage page = await _repository.fetchPage(limit: rowSize);
      final Set<String> followed = await _repository.followedAmong(_uids(page.creators));
      if (isClosed || load != _load) return;
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
    emit(state.copyWith(status: CreatorDirectoryStatus.loading, category: () => category, loadingMore: false));
    try {
      final CreatorPage page = await _repository.fetchPage(category: category);
      final Set<String> followed = await _repository.followedAmong(_uids(page.creators));
      if (isClosed || load != _load) return;
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
    final int? after = state.nextRank;
    if (after == null || state.loadingMore || state.status != CreatorDirectoryStatus.loaded) return;
    final int load = _load;
    emit(state.copyWith(loadingMore: true));
    try {
      final CreatorPage page = await _repository.fetchPage(category: state.category, afterRank: after);
      final Set<String> followed = await _repository.followedAmong(_uids(page.creators));
      if (isClosed || load != _load) return;
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
