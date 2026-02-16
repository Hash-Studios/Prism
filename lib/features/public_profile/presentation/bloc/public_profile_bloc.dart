import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/usecases/public_profile_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'public_profile_event.dart';
part 'public_profile_state.dart';
part 'public_profile_bloc.freezed.dart';

@injectable
class PublicProfileBloc extends Bloc<PublicProfileEvent, PublicProfileState> {
  PublicProfileBloc(
    this._fetchPublicProfileUseCase,
    this._fetchPublicProfileWallsUseCase,
    this._fetchPublicProfileSetupsUseCase,
    this._followUserUseCase,
    this._unfollowUserUseCase,
    this._updatePublicProfileLinksUseCase,
  ) : super(PublicProfileState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreWallsRequested>(_onFetchMoreWallsRequested);
    on<_FetchMoreSetupsRequested>(_onFetchMoreSetupsRequested);
    on<_FollowRequested>(_onFollowRequested);
    on<_UnfollowRequested>(_onUnfollowRequested);
    on<_LinksUpdated>(_onLinksUpdated);
  }

  final FetchPublicProfileUseCase _fetchPublicProfileUseCase;
  final FetchPublicProfileWallsUseCase _fetchPublicProfileWallsUseCase;
  final FetchPublicProfileSetupsUseCase _fetchPublicProfileSetupsUseCase;
  final FollowUserUseCase _followUserUseCase;
  final UnfollowUserUseCase _unfollowUserUseCase;
  final UpdatePublicProfileLinksUseCase _updatePublicProfileLinksUseCase;

  Future<void> _onStarted(
      _Started event, Emitter<PublicProfileState> emit) async {
    emit(state.copyWith(email: event.email));
    await _loadAll(emit: emit, refresh: true);
  }

  Future<void> _onRefreshRequested(
    _RefreshRequested event,
    Emitter<PublicProfileState> emit,
  ) {
    return _loadAll(emit: emit, refresh: true);
  }

  Future<void> _loadAll({
    required Emitter<PublicProfileState> emit,
    required bool refresh,
  }) async {
    if (state.email.isEmpty) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: const ValidationFailure('email is required'),
      ));
      return;
    }

    emit(state.copyWith(
      status: LoadStatus.loading,
      actionStatus: ActionStatus.inProgress,
      failure: null,
    ));

    final profileResult = await _fetchPublicProfileUseCase(
        FetchPublicProfileParams(email: state.email));
    final wallsResult = await _fetchPublicProfileWallsUseCase(
      FetchPublicProfileWallsParams(email: state.email, refresh: refresh),
    );
    final setupsResult = await _fetchPublicProfileSetupsUseCase(
      FetchPublicProfileSetupsParams(email: state.email, refresh: refresh),
    );

    if (profileResult.isFailure) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: profileResult.failure,
      ));
      return;
    }

    final profile = profileResult.data!;

    final walls = wallsResult.data?.items ?? state.walls;
    final setups = setupsResult.data?.items ?? state.setups;

    emit(state.copyWith(
      status: LoadStatus.success,
      actionStatus: ActionStatus.success,
      profile: profile,
      walls: walls,
      setups: setups,
      hasMoreWalls: wallsResult.data?.hasMore ?? state.hasMoreWalls,
      hasMoreSetups: setupsResult.data?.hasMore ?? state.hasMoreSetups,
      wallsCursor: wallsResult.data?.nextCursor,
      setupsCursor: setupsResult.data?.nextCursor,
      isFetchingMoreWalls: false,
      isFetchingMoreSetups: false,
      failure: wallsResult.failure ?? setupsResult.failure,
    ));
  }

  Future<void> _onFetchMoreWallsRequested(
    _FetchMoreWallsRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    if (state.isFetchingMoreWalls || !state.hasMoreWalls) {
      return;
    }
    emit(state.copyWith(
        isFetchingMoreWalls: true, actionStatus: ActionStatus.inProgress));

    final result = await _fetchPublicProfileWallsUseCase(
      FetchPublicProfileWallsParams(email: state.email, refresh: false),
    );

    result.fold(
      onSuccess: (page) {
        final merged = <PublicProfileWallEntity>[...state.walls, ...page.items];
        final deduped = <String, PublicProfileWallEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(state.copyWith(
          actionStatus: ActionStatus.success,
          walls: deduped,
          hasMoreWalls: page.hasMore,
          wallsCursor: page.nextCursor,
          isFetchingMoreWalls: false,
          failure: null,
        ));
      },
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        isFetchingMoreWalls: false,
        failure: failure,
      )),
    );
  }

  Future<void> _onFetchMoreSetupsRequested(
    _FetchMoreSetupsRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    if (state.isFetchingMoreSetups || !state.hasMoreSetups) {
      return;
    }
    emit(state.copyWith(
        isFetchingMoreSetups: true, actionStatus: ActionStatus.inProgress));

    final result = await _fetchPublicProfileSetupsUseCase(
      FetchPublicProfileSetupsParams(email: state.email, refresh: false),
    );

    result.fold(
      onSuccess: (page) {
        final merged = <PublicProfileSetupEntity>[
          ...state.setups,
          ...page.items
        ];
        final deduped = <String, PublicProfileSetupEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(state.copyWith(
          actionStatus: ActionStatus.success,
          setups: deduped,
          hasMoreSetups: page.hasMore,
          setupsCursor: page.nextCursor,
          isFetchingMoreSetups: false,
          failure: null,
        ));
      },
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        isFetchingMoreSetups: false,
        failure: failure,
      )),
    );
  }

  Future<void> _onFollowRequested(
    _FollowRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    if (state.profile.id.isEmpty || state.profile.email.isEmpty) {
      emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: const ValidationFailure('No target profile loaded'),
      ));
      return;
    }

    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _followUserUseCase(
      FollowUserParams(
        currentUserId: event.currentUserId,
        currentUserEmail: event.currentUserEmail,
        targetUserId: state.profile.id,
        targetUserEmail: state.profile.email,
      ),
    );

    result.fold(
      onSuccess: (profile) => emit(state.copyWith(
        actionStatus: ActionStatus.success,
        profile: profile,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onUnfollowRequested(
    _UnfollowRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    if (state.profile.id.isEmpty || state.profile.email.isEmpty) {
      emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: const ValidationFailure('No target profile loaded'),
      ));
      return;
    }

    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _unfollowUserUseCase(
      UnfollowUserParams(
        currentUserId: event.currentUserId,
        currentUserEmail: event.currentUserEmail,
        targetUserId: state.profile.id,
        targetUserEmail: state.profile.email,
      ),
    );

    result.fold(
      onSuccess: (profile) => emit(state.copyWith(
        actionStatus: ActionStatus.success,
        profile: profile,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onLinksUpdated(
    _LinksUpdated event,
    Emitter<PublicProfileState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _updatePublicProfileLinksUseCase(
      UpdatePublicProfileLinksParams(userId: event.userId, links: event.links),
    );

    result.fold(
      onSuccess: (profile) => emit(state.copyWith(
        actionStatus: ActionStatus.success,
        profile: profile,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }
}
