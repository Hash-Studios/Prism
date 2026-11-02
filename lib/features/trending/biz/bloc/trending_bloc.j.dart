import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'trending_event.j.dart';
part 'trending_state.j.dart';
part 'trending_bloc.j.freezed.dart';

typedef _TrendingRequest = ({int id, int startupGeneration, int sessionGeneration, (String, bool)? sessionKey});

@injectable
class TrendingBloc extends Bloc<TrendingEvent, TrendingState> {
  TrendingBloc(
    this._fetchTrendingUseCase,
    this._userBlockRepository, {
    @ignoreParam SessionRepository? sessionRepository,
  }) : super(TrendingState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>((event, emit) => _load(emit));
    on<_StartupRetryRequested>((event, emit) async {
      if (event.requestId != _latestRequestId ||
          event.generation != _startupGeneration ||
          _sessionKey != _currentSessionKey ||
          _startupRetryAttempted) {
        return;
      }
      _startupRetryAttempted = true;
      await _load(emit);
    });
    on<_BlockedCreatorsChanged>(_onBlockedCreatorsChanged);
    _blocked = _userBlockRepository.blockedCreators;
    _blockedCreatorsSub = _userBlockRepository.watchBlockedCreators().listen((blocked) {
      if (blocked is UnknownBlockedCreators) _blocked = blocked;
      add(const TrendingEvent.blockedCreatorsChanged());
    });
    _sessionRepository =
        sessionRepository ?? (getIt.isRegistered<SessionRepository>() ? getIt<SessionRepository>() : null);
    _sessionKey = _currentSessionKey;
    _sessionSub = _sessionRepository?.watchCurrentUser().listen((user) {
      final key = (user.id, user.loggedIn);
      if (key != _sessionKey) {
        _sessionKey = key;
        _sessionGeneration++;
        _startupGeneration++;
        if (!isClosed &&
            _latestRequestId > 0 &&
            (state.status == LoadStatus.initial || state.status == LoadStatus.loading)) {
          add(const TrendingEvent.refreshRequested());
        }
      }
    });
  }

  final FetchTrendingUseCase _fetchTrendingUseCase;
  final UserBlockRepository _userBlockRepository;
  StreamSubscription<BlockedCreators>? _blockedCreatorsSub;
  BlockedCreators _blocked = const UnknownBlockedCreators();
  int _latestRequestId = 0;
  SessionRepository? _sessionRepository;
  StreamSubscription<Object?>? _sessionSub;
  (String, bool)? _sessionKey;
  int _startupGeneration = 0;
  int _sessionGeneration = 0;
  bool _startupRetryAttempted = false;
  bool _blockRecoveryDuringLoad = false;

  (String, bool)? get _currentSessionKey {
    final user = _sessionRepository?.currentUser;
    return user == null ? null : (user.id, user.loggedIn);
  }

  _TrendingRequest _beginRequest() => (
    id: ++_latestRequestId,
    startupGeneration: _startupGeneration,
    sessionGeneration: _sessionGeneration,
    sessionKey: _currentSessionKey,
  );

  bool _ownsRequest(_TrendingRequest request) =>
      request.id == _latestRequestId &&
      request.sessionGeneration == _sessionGeneration &&
      request.sessionKey == _currentSessionKey;

  @override
  void add(TrendingEvent event) {
    if (event is _Started || event is _RefreshRequested) {
      _startupGeneration++;
    }
    super.add(event);
  }

  /// Blocking a creator removes their walls at once, without waiting for the next load. Unblocking one loads the list
  /// again, because their walls were dropped from the state.
  Future<void> _onBlockedCreatorsChanged(_BlockedCreatorsChanged event, Emitter<TrendingState> emit) async {
    final BlockedCreators current = _userBlockRepository.blockedCreators;
    if (current is UnknownBlockedCreators) {
      _blocked = current;
      final List<PrismWallpaper> visible = _withoutBlocked(state.walls);
      if (visible.length != state.walls.length) emit(state.copyWith(walls: visible));
      return;
    }
    final bool recovered = _blocked is UnknownBlockedCreators;
    final Set<String> oldUids = _blocked is KnownBlockedCreators ? (_blocked as KnownBlockedCreators).uids : const {};
    final KnownBlockedCreators known = current as KnownBlockedCreators;
    final bool unblocked = oldUids.any((uid) => !known.uids.contains(uid));
    _blocked = known;
    if (unblocked || recovered) {
      if (state.status == LoadStatus.loading) {
        _blockRecoveryDuringLoad = true;
        return;
      }
      _blockRecoveryDuringLoad = false;
      if (state.status != LoadStatus.initial) await _load(emit);
      return;
    }
    if (known.uids.isEmpty) return;
    final List<PrismWallpaper> visible = _withoutBlocked(state.walls);
    if (visible.length != state.walls.length) emit(state.copyWith(walls: visible));
  }

  List<PrismWallpaper> _withoutBlocked(List<PrismWallpaper> walls) => walls
      .where((wall) => !BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, _blocked))
      .toList(growable: false);

  @override
  Future<void> close() {
    _startupGeneration++;
    unawaited(_sessionSub?.cancel());
    unawaited(_blockedCreatorsSub?.cancel());
    return super.close();
  }

  /// Paints the saved walls at once when none are on screen, then loads the fresh list behind them.
  Future<void> _onStarted(_Started event, Emitter<TrendingState> emit) async {
    final request = _beginRequest();
    final Future<TrendingFetch> fresh = _fetchTrendingUseCase(const NoParams())..ignore();
    if (state.walls.isEmpty) {
      List<PrismWallpaper> cached = const <PrismWallpaper>[];
      try {
        cached = _withoutBlocked(await _fetchTrendingUseCase.readCached());
      } catch (_) {}
      if (emit.isDone || !_ownsRequest(request)) return;
      if (cached.isNotEmpty && state.walls.isEmpty) {
        emit(state.copyWith(status: LoadStatus.success, walls: cached));
      }
    }
    if (emit.isDone || !_ownsRequest(request)) return;
    return _load(emit, pending: fresh, request: request);
  }

  /// Keeps the walls on screen while a refresh runs, and when it fails. [pending] is a fetch already under way.
  Future<void> _load(Emitter<TrendingState> emit, {Future<TrendingFetch>? pending, _TrendingRequest? request}) async {
    final active = request ?? _beginRequest();
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await (pending ?? _fetchTrendingUseCase(const NoParams()));
    if (emit.isDone || !_ownsRequest(active)) return;
    result.result.fold(
      onSuccess: (walls) => emit(state.copyWith(status: LoadStatus.success, walls: _withoutBlocked(walls))),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
    if (_blockRecoveryDuringLoad) {
      _blockRecoveryDuringLoad = false;
      await _load(emit);
    }
    final ready = result.retryAfterInitialization;
    if (ready == null || _startupRetryAttempted) return;
    unawaited(
      ready.then((initialized) {
        if (!initialized || isClosed || !_ownsRequest(active) || active.startupGeneration != _startupGeneration) {
          return;
        }
        add(TrendingEvent.startupRetryRequested(requestId: active.id, generation: active.startupGeneration));
      }, onError: (Object _, StackTrace _) {}),
    );
  }
}
