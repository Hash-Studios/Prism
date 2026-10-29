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

  Future<void> load(WallRequestTab tab) async {
    final int version = (_loads[tab] ?? 0) + 1;
    _loads[tab] = version;
    if (state.tab(tab) is! WallRequestsTabLoaded) _setTab(tab, const WallRequestsTabLoading());
    try {
      final List<WallRequest> requests = await _repository.list(tab);
      if (_loads[tab] == version) _setTab(tab, WallRequestsTabLoaded(requests));
    } catch (error, stackTrace) {
      logger.w('[WallRequestsCubit] load failed', error: error, stackTrace: stackTrace);
      if (_loads[tab] == version) _setTab(tab, const WallRequestsTabFailed());
    }
  }

  Future<void> toggleVote(WallRequest request, WallRequestTab from) async {
    if (!request.canVote) return;
    final bool vote = !request.voted;
    _replace(request.copyWith(voted: vote, voteCount: request.voteCount + (vote ? 1 : -1)));
    try {
      final int count = await _repository.setVote(request.id, vote: vote);
      _replace(request.copyWith(voted: vote, voteCount: count));
      analytics.track(WallRequestVoteToggledEvent(voted: vote, tab: from.wire));
    } on WallRequestException catch (e) {
      _replace(request);
      _emitError(e.error);
    } catch (error, stackTrace) {
      logger.w('[WallRequestsCubit] vote failed', error: error, stackTrace: stackTrace);
      _replace(request);
      _emitError(WallRequestError.unknown);
    }
  }

  Future<void> setHidden(WallRequest request, {required bool hidden}) async {
    try {
      await _repository.setHidden(request.id, hidden: hidden);
      _replace(request.copyWith(hidden: hidden));
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

  /// The same request can show in Top and New, so every tab gets the change.
  void _replace(WallRequest request) {
    if (isClosed) return;
    emit(
      WallRequestsState(
        tabs: state.tabs.map((WallRequestTab tab, WallRequestsTabState value) {
          if (value is! WallRequestsTabLoaded) return MapEntry<WallRequestTab, WallRequestsTabState>(tab, value);
          return MapEntry<WallRequestTab, WallRequestsTabState>(
            tab,
            WallRequestsTabLoaded(value.requests.map((WallRequest r) => r.id == request.id ? request : r).toList()),
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
