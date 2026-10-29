import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/domain/repositories/wall_requests_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

sealed class WallRequestsTabState {
  const WallRequestsTabState();
}

final class WallRequestsTabLoading extends WallRequestsTabState {
  const WallRequestsTabLoading();
}

final class WallRequestsTabLoaded extends WallRequestsTabState {
  const WallRequestsTabLoaded(this.requests);

  final List<WallRequest> requests;
}

final class WallRequestsTabFailed extends WallRequestsTabState {
  const WallRequestsTabFailed();
}

class WallRequestsState {
  const WallRequestsState({required this.tabs, this.error});

  WallRequestsState.initial()
    : this(
        tabs: <WallRequestTab, WallRequestsTabState>{
          for (final WallRequestTab tab in WallRequestTab.values) tab: const WallRequestsTabLoading(),
        },
      );

  final Map<WallRequestTab, WallRequestsTabState> tabs;

  /// The last vote or hide that failed. The page shows it once as a toast.
  final WallRequestError? error;

  WallRequestsTabState tab(WallRequestTab tab) => tabs[tab] ?? const WallRequestsTabLoading();
}

/// The three tabs of the requests page. Votes change the row at once and go back when the server refuses them.
@injectable
class WallRequestsCubit extends Cubit<WallRequestsState> {
  WallRequestsCubit(this._repository) : super(WallRequestsState.initial());

  final WallRequestsRepository _repository;
  final Map<WallRequestTab, int> _loads = <WallRequestTab, int>{};
  final Map<String, int> _requestVoteVersions = <String, int>{};
  final Map<String, int> _requestHiddenVersions = <String, int>{};
  final Set<String> _pendingVotes = <String>{};
  int _voteVersion = 0;
  int _hiddenVersion = 0;

  Future<void> load(WallRequestTab tab) async {
    final int version = (_loads[tab] ?? 0) + 1;
    final int voteVersionAtStart = _voteVersion;
    final int hiddenVersionAtStart = _hiddenVersion;
    _loads[tab] = version;
    if (state.tab(tab) is! WallRequestsTabLoaded) _setTab(tab, const WallRequestsTabLoading());
    try {
      final List<WallRequest> requests = await _repository.list(tab);
      if (_loads[tab] == version) {
        _setTab(
          tab,
          WallRequestsTabLoaded(
            _preserveRecentHidden(_preserveRecentVotes(requests, voteVersionAtStart), hiddenVersionAtStart),
          ),
        );
      }
    } catch (error, stackTrace) {
      logger.w('[WallRequestsCubit] load failed', error: error, stackTrace: stackTrace);
      if (_loads[tab] == version) _setTab(tab, const WallRequestsTabFailed());
    }
  }

  Future<void> toggleVote(WallRequest request, WallRequestTab from) async {
    final WallRequest current = _currentRequest(request.id) ?? request;
    if (!current.canVote || !_pendingVotes.add(current.id)) return;
    final bool vote = !current.voted;
    _replaceVote(current.id, voted: vote, voteCount: current.voteCount + (vote ? 1 : -1));
    try {
      final int count = await _repository.setVote(current.id, vote: vote);
      _replaceVote(current.id, voted: vote, voteCount: count);
      analytics.track(WallRequestVoteToggledEvent(voted: vote, tab: from.wire));
    } on WallRequestException catch (e) {
      _replaceVote(current.id, voted: current.voted, voteCount: current.voteCount);
      _emitError(e.error);
    } catch (error, stackTrace) {
      logger.w('[WallRequestsCubit] vote failed', error: error, stackTrace: stackTrace);
      _replaceVote(current.id, voted: current.voted, voteCount: current.voteCount);
      _emitError(WallRequestError.unknown);
    } finally {
      _pendingVotes.remove(current.id);
    }
  }

  Future<void> setHidden(WallRequest request, {required bool hidden}) async {
    try {
      await _repository.setHidden(request.id, hidden: hidden);
      _replaceHidden(request.id, hidden: hidden);
    } on WallRequestException catch (e) {
      _emitError(e.error);
    } catch (error, stackTrace) {
      logger.w('[WallRequestsCubit] hide failed', error: error, stackTrace: stackTrace);
      _emitError(WallRequestError.unknown);
    }
  }

  void clearError() {
    if (!isClosed && state.error != null) emit(WallRequestsState(tabs: state.tabs));
  }

  void _setTab(WallRequestTab tab, WallRequestsTabState value) {
    if (isClosed) return;
    emit(
      WallRequestsState(tabs: <WallRequestTab, WallRequestsTabState>{...state.tabs, tab: value}, error: state.error),
    );
  }

  WallRequest? _currentRequest(String id) {
    for (final WallRequestsTabState tab in state.tabs.values) {
      if (tab is! WallRequestsTabLoaded) continue;
      for (final WallRequest request in tab.requests) {
        if (request.id == id) return request;
      }
    }
    return null;
  }

  /// The same request can show in Top and New, so every tab gets the change.
  void _replaceVote(String id, {required bool voted, required int voteCount}) {
    _requestVoteVersions[id] = ++_voteVersion;
    _updateRequest(id, (WallRequest request) => request.copyWith(voted: voted, voteCount: voteCount));
  }

  List<WallRequest> _preserveRecentVotes(List<WallRequest> requests, int versionAtStart) => requests
      .map((WallRequest request) {
        if (!_pendingVotes.contains(request.id) && (_requestVoteVersions[request.id] ?? 0) <= versionAtStart) {
          return request;
        }
        final WallRequest? current = _currentRequest(request.id);
        return current == null ? request : request.copyWith(voted: current.voted, voteCount: current.voteCount);
      })
      .toList(growable: false);

  List<WallRequest> _preserveRecentHidden(List<WallRequest> requests, int versionAtStart) => requests
      .map((WallRequest request) {
        if ((_requestHiddenVersions[request.id] ?? 0) <= versionAtStart) return request;
        final WallRequest? current = _currentRequest(request.id);
        return current == null ? request : request.copyWith(hidden: current.hidden);
      })
      .toList(growable: false);

  void _replaceHidden(String id, {required bool hidden}) {
    _requestHiddenVersions[id] = ++_hiddenVersion;
    _updateRequest(id, (WallRequest request) => request.copyWith(hidden: hidden));
  }

  void _updateRequest(String id, WallRequest Function(WallRequest) update) {
    if (isClosed) return;
    emit(
      WallRequestsState(
        tabs: state.tabs.map((WallRequestTab tab, WallRequestsTabState value) {
          if (value is! WallRequestsTabLoaded) return MapEntry<WallRequestTab, WallRequestsTabState>(tab, value);
          return MapEntry<WallRequestTab, WallRequestsTabState>(
            tab,
            WallRequestsTabLoaded(value.requests.map((WallRequest r) => r.id == id ? update(r) : r).toList()),
          );
        }),
        error: state.error,
      ),
    );
  }

  void _emitError(WallRequestError error) {
    if (!isClosed) emit(WallRequestsState(tabs: state.tabs, error: error));
  }
}
