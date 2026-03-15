import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/usecases/public_profile_usecases.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:bloc/bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

part 'public_profile_event.j.dart';
part 'public_profile_state.j.dart';
part 'public_profile_bloc.j.freezed.dart';

@injectable
class PublicProfileBloc extends Bloc<PublicProfileEvent, PublicProfileState> {
  PublicProfileBloc(
    this._fetchPublicProfileUseCase,
    this._fetchPublicProfileWallsUseCase,
    this._fetchPublicProfileSetupsUseCase,
    this._followUserUseCase,
    this._unfollowUserUseCase,
    this._updatePublicProfileLinksUseCase,
    this._fetchUserSummariesPageUseCase,
    this._searchUsersByUsernameUseCase,
  ) : super(PublicProfileState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreWallsRequested>(_onFetchMoreWallsRequested);
    on<_FetchMoreSetupsRequested>(_onFetchMoreSetupsRequested);
    on<_FollowRequested>(_onFollowRequested);
    on<_UnfollowRequested>(_onUnfollowRequested);
    on<_LinksUpdated>(_onLinksUpdated);
    on<_FetchFollowerSummariesPageRequested>(_onFetchFollowerSummariesPageRequested);
    on<_FetchFollowingSummariesPageRequested>(_onFetchFollowingSummariesPageRequested);
    on<_SearchFollowerSummariesRequested>(_onSearchFollowerSummariesRequested);
    on<_SearchFollowingSummariesRequested>(_onSearchFollowingSummariesRequested);
    on<_ClearFollowerSearch>(_onClearFollowerSearch);
    on<_ClearFollowingSearch>(_onClearFollowingSearch);
    on<_FollowFromListRequested>(_onFollowFromListRequested);
    on<_UnfollowFromListRequested>(_onUnfollowFromListRequested);
  }

  final FetchPublicProfileUseCase _fetchPublicProfileUseCase;
  final FetchPublicProfileWallsUseCase _fetchPublicProfileWallsUseCase;
  final FetchPublicProfileSetupsUseCase _fetchPublicProfileSetupsUseCase;
  final FollowUserUseCase _followUserUseCase;
  final UnfollowUserUseCase _unfollowUserUseCase;
  final UpdatePublicProfileLinksUseCase _updatePublicProfileLinksUseCase;
  final FetchUserSummariesPageUseCase _fetchUserSummariesPageUseCase;
  final SearchUsersByUsernameUseCase _searchUsersByUsernameUseCase;

  Future<void> _onStarted(_Started event, Emitter<PublicProfileState> emit) async {
    emit(state.copyWith(email: event.email));
    await _loadAll(emit: emit, refresh: true);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<PublicProfileState> emit) {
    return _loadAll(emit: emit, refresh: true);
  }

  Future<void> _loadAll({required Emitter<PublicProfileState> emit, required bool refresh}) async {
    if (state.email.isEmpty) {
      emit(
        state.copyWith(
          status: LoadStatus.failure,
          actionStatus: ActionStatus.failure,
          failure: const ValidationFailure('email is required'),
        ),
      );
      return;
    }

    emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress, failure: null));

    final profileResult = await _fetchPublicProfileUseCase(FetchPublicProfileParams(email: state.email));
    final wallsResult = await _fetchPublicProfileWallsUseCase(
      FetchPublicProfileWallsParams(email: state.email, refresh: refresh),
    );
    final setupsResult = await _fetchPublicProfileSetupsUseCase(
      FetchPublicProfileSetupsParams(email: state.email, refresh: refresh),
    );

    if (profileResult.isFailure) {
      emit(
        state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: profileResult.failure),
      );
      return;
    }

    final profile = profileResult.data!;

    final walls = wallsResult.data?.items ?? state.walls;
    final setups = setupsResult.data?.items ?? state.setups;

    emit(
      state.copyWith(
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
      ),
    );
  }

  Future<void> _onFetchMoreWallsRequested(_FetchMoreWallsRequested event, Emitter<PublicProfileState> emit) async {
    if (state.isFetchingMoreWalls || !state.hasMoreWalls) {
      return;
    }
    emit(state.copyWith(isFetchingMoreWalls: true, actionStatus: ActionStatus.inProgress));

    final result = await _fetchPublicProfileWallsUseCase(
      FetchPublicProfileWallsParams(email: state.email, refresh: false),
    );

    result.fold(
      onSuccess: (page) {
        final merged = <PublicProfileWallEntity>[...state.walls, ...page.items];
        final deduped = <String, PublicProfileWallEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            walls: deduped,
            hasMoreWalls: page.hasMore,
            wallsCursor: page.nextCursor,
            isFetchingMoreWalls: false,
            failure: null,
          ),
        );
      },
      onFailure: (failure) =>
          emit(state.copyWith(actionStatus: ActionStatus.failure, isFetchingMoreWalls: false, failure: failure)),
    );
  }

  Future<void> _onFetchMoreSetupsRequested(_FetchMoreSetupsRequested event, Emitter<PublicProfileState> emit) async {
    if (state.isFetchingMoreSetups || !state.hasMoreSetups) {
      return;
    }
    emit(state.copyWith(isFetchingMoreSetups: true, actionStatus: ActionStatus.inProgress));

    final result = await _fetchPublicProfileSetupsUseCase(
      FetchPublicProfileSetupsParams(email: state.email, refresh: false),
    );

    result.fold(
      onSuccess: (page) {
        final merged = <PublicProfileSetupEntity>[...state.setups, ...page.items];
        final deduped = <String, PublicProfileSetupEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            setups: deduped,
            hasMoreSetups: page.hasMore,
            setupsCursor: page.nextCursor,
            isFetchingMoreSetups: false,
            failure: null,
          ),
        );
      },
      onFailure: (failure) =>
          emit(state.copyWith(actionStatus: ActionStatus.failure, isFetchingMoreSetups: false, failure: failure)),
    );
  }

  Future<void> _onFollowRequested(_FollowRequested event, Emitter<PublicProfileState> emit) async {
    if (state.profile.id.isEmpty || state.profile.email.isEmpty) {
      emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          failure: const ValidationFailure('No target profile loaded'),
        ),
      );
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
      onSuccess: (profile) {
        // Subscribe to the artist's posts topic so the user gets push
        // notifications when that artist publishes a new wallpaper.
        final String artistEmailPrefix = profile.email.split('@')[0];
        if (artistEmailPrefix.isNotEmpty) {
          unawaited(
            subscribeToTopicSafely(
              FirebaseMessaging.instance,
              '${artistEmailPrefix}_posts',
              sourceTag: 'follow.subscribe_posts_topic',
            ),
          );
        }
        emit(state.copyWith(actionStatus: ActionStatus.success, profile: profile, failure: null));
      },
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onUnfollowRequested(_UnfollowRequested event, Emitter<PublicProfileState> emit) async {
    if (state.profile.id.isEmpty || state.profile.email.isEmpty) {
      emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          failure: const ValidationFailure('No target profile loaded'),
        ),
      );
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
      onSuccess: (profile) {
        // Unsubscribe from the artist's posts topic — the user no longer
        // wants notifications for this artist's new walls.
        final String artistEmailPrefix = profile.email.split('@')[0];
        if (artistEmailPrefix.isNotEmpty) {
          unawaited(
            unsubscribeFromTopicSafely(
              FirebaseMessaging.instance,
              '${artistEmailPrefix}_posts',
              sourceTag: 'unfollow.unsubscribe_posts_topic',
            ),
          );
        }
        emit(state.copyWith(actionStatus: ActionStatus.success, profile: profile, failure: null));
      },
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onLinksUpdated(_LinksUpdated event, Emitter<PublicProfileState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _updatePublicProfileLinksUseCase(
      UpdatePublicProfileLinksParams(userId: event.userId, links: event.links),
    );

    result.fold(
      onSuccess: (profile) => emit(state.copyWith(actionStatus: ActionStatus.success, profile: profile, failure: null)),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onFetchFollowerSummariesPageRequested(
    _FetchFollowerSummariesPageRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    if (state.isFetchingFollowers) return;
    if (event.page > 0 && !state.hasMoreFollowers) return;

    emit(state.copyWith(isFetchingFollowers: true, failure: null));

    final result = await _fetchUserSummariesPageUseCase(
      FetchUserSummariesPageParams(
        allEmails: event.allEmails,
        currentUserEmail: event.currentUserEmail,
        page: event.page,
        pageSize: event.pageSize,
      ),
    );

    result.fold(
      onSuccess: (page) {
        final merged = event.page == 0 ? page.items : <UserSummaryEntity>[...state.followerSummaries, ...page.items];
        final deduped = <String, UserSummaryEntity>{
          for (final s in merged) s.email.toLowerCase(): s,
        }.values.toList(growable: false);
        emit(
          state.copyWith(
            followerSummaries: deduped,
            followerPage: event.page,
            hasMoreFollowers: page.hasMore,
            isFetchingFollowers: false,
            failure: null,
          ),
        );
      },
      onFailure: (failure) => emit(state.copyWith(isFetchingFollowers: false, failure: failure)),
    );
  }

  Future<void> _onFetchFollowingSummariesPageRequested(
    _FetchFollowingSummariesPageRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    if (state.isFetchingFollowing) return;
    if (event.page > 0 && !state.hasMoreFollowing) return;

    emit(state.copyWith(isFetchingFollowing: true, failure: null));

    final result = await _fetchUserSummariesPageUseCase(
      FetchUserSummariesPageParams(
        allEmails: event.allEmails,
        currentUserEmail: event.currentUserEmail,
        page: event.page,
        pageSize: event.pageSize,
      ),
    );

    result.fold(
      onSuccess: (page) {
        final merged = event.page == 0 ? page.items : <UserSummaryEntity>[...state.followingSummaries, ...page.items];
        final deduped = <String, UserSummaryEntity>{
          for (final s in merged) s.email.toLowerCase(): s,
        }.values.toList(growable: false);
        emit(
          state.copyWith(
            followingSummaries: deduped,
            followingPage: event.page,
            hasMoreFollowing: page.hasMore,
            isFetchingFollowing: false,
            failure: null,
          ),
        );
      },
      onFailure: (failure) => emit(state.copyWith(isFetchingFollowing: false, failure: failure)),
    );
  }

  Future<void> _onSearchFollowerSummariesRequested(
    _SearchFollowerSummariesRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    emit(state.copyWith(isSearchingFollowers: true, followerSearchResults: const <UserSummaryEntity>[]));
    final result = await _searchUsersByUsernameUseCase(
      SearchUsersByUsernameParams(
        query: event.query,
        scopeEmails: event.allEmails,
        currentUserEmail: event.currentUserEmail,
      ),
    );
    result.fold(
      onSuccess: (summaries) => emit(state.copyWith(followerSearchResults: summaries, isSearchingFollowers: false)),
      onFailure: (_) =>
          emit(state.copyWith(isSearchingFollowers: false, followerSearchResults: const <UserSummaryEntity>[])),
    );
  }

  Future<void> _onSearchFollowingSummariesRequested(
    _SearchFollowingSummariesRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    emit(state.copyWith(isSearchingFollowing: true, followingSearchResults: const <UserSummaryEntity>[]));
    final result = await _searchUsersByUsernameUseCase(
      SearchUsersByUsernameParams(
        query: event.query,
        scopeEmails: event.allEmails,
        currentUserEmail: event.currentUserEmail,
      ),
    );
    result.fold(
      onSuccess: (summaries) => emit(state.copyWith(followingSearchResults: summaries, isSearchingFollowing: false)),
      onFailure: (_) =>
          emit(state.copyWith(isSearchingFollowing: false, followingSearchResults: const <UserSummaryEntity>[])),
    );
  }

  void _onClearFollowerSearch(_ClearFollowerSearch event, Emitter<PublicProfileState> emit) {
    emit(state.copyWith(followerSearchResults: null, isSearchingFollowers: false));
  }

  void _onClearFollowingSearch(_ClearFollowingSearch event, Emitter<PublicProfileState> emit) {
    emit(state.copyWith(followingSearchResults: null, isSearchingFollowing: false));
  }

  Future<void> _onFollowFromListRequested(_FollowFromListRequested event, Emitter<PublicProfileState> emit) async {
    final result = await _followUserUseCase(
      FollowUserParams(
        currentUserId: event.currentUserId,
        currentUserEmail: event.currentUserEmail,
        targetUserId: event.targetUserId,
        targetUserEmail: event.targetUserEmail,
      ),
    );
    if (result.isSuccess) {
      final String artistEmailPrefix = event.targetUserEmail.split('@')[0];
      if (artistEmailPrefix.isNotEmpty) {
        unawaited(
          subscribeToTopicSafely(
            FirebaseMessaging.instance,
            '${artistEmailPrefix}_posts',
            sourceTag: 'follow_from_list.subscribe_posts_topic',
          ),
        );
      }
      emit(
        state.copyWith(
          followerSummaries: _updateSummaryFollowState(
            state.followerSummaries,
            event.targetUserEmail,
            isFollowed: true,
          ),
          followingSummaries: _updateSummaryFollowState(
            state.followingSummaries,
            event.targetUserEmail,
            isFollowed: true,
          ),
          followerSearchResults: state.followerSearchResults == null
              ? null
              : _updateSummaryFollowState(state.followerSearchResults!, event.targetUserEmail, isFollowed: true),
          followingSearchResults: state.followingSearchResults == null
              ? null
              : _updateSummaryFollowState(state.followingSearchResults!, event.targetUserEmail, isFollowed: true),
        ),
      );
    }
  }

  Future<void> _onUnfollowFromListRequested(_UnfollowFromListRequested event, Emitter<PublicProfileState> emit) async {
    final result = await _unfollowUserUseCase(
      UnfollowUserParams(
        currentUserId: event.currentUserId,
        currentUserEmail: event.currentUserEmail,
        targetUserId: event.targetUserId,
        targetUserEmail: event.targetUserEmail,
      ),
    );
    if (result.isSuccess) {
      final String artistEmailPrefix = event.targetUserEmail.split('@')[0];
      if (artistEmailPrefix.isNotEmpty) {
        unawaited(
          unsubscribeFromTopicSafely(
            FirebaseMessaging.instance,
            '${artistEmailPrefix}_posts',
            sourceTag: 'unfollow_from_list.unsubscribe_posts_topic',
          ),
        );
      }
      emit(
        state.copyWith(
          followerSummaries: _updateSummaryFollowState(
            state.followerSummaries,
            event.targetUserEmail,
            isFollowed: false,
          ),
          followingSummaries: _updateSummaryFollowState(
            state.followingSummaries,
            event.targetUserEmail,
            isFollowed: false,
          ),
          followerSearchResults: state.followerSearchResults == null
              ? null
              : _updateSummaryFollowState(state.followerSearchResults!, event.targetUserEmail, isFollowed: false),
          followingSearchResults: state.followingSearchResults == null
              ? null
              : _updateSummaryFollowState(state.followingSearchResults!, event.targetUserEmail, isFollowed: false),
        ),
      );
    }
  }

  List<UserSummaryEntity> _updateSummaryFollowState(
    List<UserSummaryEntity> summaries,
    String targetEmail, {
    required bool isFollowed,
  }) {
    return summaries
        .map((s) {
          if (s.email.toLowerCase() == targetEmail.toLowerCase()) {
            return s.copyWith(isFollowedByCurrentUser: isFollowed);
          }
          return s;
        })
        .toList(growable: false);
  }
}
