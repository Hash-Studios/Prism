import 'dart:async';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/usecases/public_profile_usecases.dart';
import 'package:Prism/logger/logger.dart';
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
    this._fetchPublicProfileWallsUseCase,
    this._followUserUseCase,
    this._unfollowUserUseCase,
    this._fetchUserSummariesPageUseCase,
    this._searchUsersByUsernameUseCase,
  ) : super(PublicProfileState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreWallsRequested>(_onFetchMoreWallsRequested);
    on<_RelationPageRequested>(_onRelationPageRequested);
    on<_RelationSearchRequested>(_onRelationSearchRequested);
    on<_RelationSearchCleared>(_onRelationSearchCleared);
    on<_FollowChangeRequested>(_onFollowChangeRequested);
  }

  // Only the newest search may write results; slower earlier ones are dropped.
  final Map<UserRelationKind, String> _latestQuery = <UserRelationKind, String>{};

  final FetchPublicProfileWallsUseCase _fetchPublicProfileWallsUseCase;
  final FollowUserUseCase _followUserUseCase;
  final UnfollowUserUseCase _unfollowUserUseCase;
  final FetchUserSummariesPageUseCase _fetchUserSummariesPageUseCase;
  final SearchUsersByUsernameUseCase _searchUsersByUsernameUseCase;

  Future<void> _onStarted(_Started event, Emitter<PublicProfileState> emit) async {
    // Clear previous user's walls immediately so UI never flashes stale grids.
    emit(
      state.copyWith(
        email: event.email,
        status: LoadStatus.loading,
        walls: const <PublicProfileWallEntity>[],
        hasMoreWalls: true,
        isFetchingMoreWalls: false,
      ),
    );
    await _loadAll(emit: emit, refresh: true);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<PublicProfileState> emit) {
    return _loadAll(emit: emit, refresh: true);
  }

  Future<void> _loadAll({required Emitter<PublicProfileState> emit, required bool refresh}) async {
    if (state.email.isEmpty) {
      emit(state.copyWith(status: LoadStatus.failure));
      return;
    }

    emit(state.copyWith(status: LoadStatus.loading));

    final wallsResult = await _fetchPublicProfileWallsUseCase(
      FetchPublicProfileWallsParams(email: state.email, refresh: refresh),
    );

    final bool failedWithNothingToShow = wallsResult.isFailure && state.walls.isEmpty;
    emit(
      state.copyWith(
        status: failedWithNothingToShow ? LoadStatus.failure : LoadStatus.success,
        walls: wallsResult.data?.items ?? state.walls,
        hasMoreWalls: wallsResult.data?.hasMore ?? state.hasMoreWalls,
        isFetchingMoreWalls: false,
      ),
    );
  }

  Future<void> _onFetchMoreWallsRequested(_FetchMoreWallsRequested event, Emitter<PublicProfileState> emit) async {
    if (state.isFetchingMoreWalls || !state.hasMoreWalls) {
      return;
    }
    emit(state.copyWith(isFetchingMoreWalls: true));

    final result = await _fetchPublicProfileWallsUseCase(
      FetchPublicProfileWallsParams(email: state.email, refresh: false),
    );

    result.fold(
      onSuccess: (page) {
        final merged = <PublicProfileWallEntity>[...state.walls, ...page.items];
        final deduped = <String, PublicProfileWallEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(state.copyWith(walls: deduped, hasMoreWalls: page.hasMore, isFetchingMoreWalls: false));
      },
      onFailure: (_) => emit(state.copyWith(isFetchingMoreWalls: false)),
    );
  }

  void _emitRelation(
    UserRelationKind kind,
    Emitter<PublicProfileState> emit,
    RelationList Function(RelationList list) update,
  ) {
    final RelationList next = update(state.relation(kind));
    emit(kind == UserRelationKind.followers ? state.copyWith(followers: next) : state.copyWith(following: next));
  }

  Future<void> _onRelationPageRequested(_RelationPageRequested event, Emitter<PublicProfileState> emit) async {
    final UserRelationKind kind = event.kind;
    final RelationList current = state.relation(kind);
    if (current.isFetching) return;
    if (event.page > 0 && !current.hasMore) return;

    _emitRelation(kind, emit, (list) => list.copyWith(isFetching: true));

    final result = await _fetchUserSummariesPageUseCase(
      FetchUserSummariesPageParams(allEmails: event.allEmails, page: event.page),
    );

    result.fold(
      onSuccess: (page) {
        final merged = event.page == 0
            ? page.items
            : <UserSummaryEntity>[...state.relation(kind).summaries, ...page.items];
        final deduped = <String, UserSummaryEntity>{
          for (final s in merged) s.email.toLowerCase(): s,
        }.values.toList(growable: false);
        _emitRelation(
          kind,
          emit,
          (list) => list.copyWith(summaries: deduped, page: event.page, hasMore: page.hasMore, isFetching: false),
        );
      },
      onFailure: (_) => _emitRelation(kind, emit, (list) => list.copyWith(isFetching: false)),
    );
  }

  Future<void> _onRelationSearchRequested(_RelationSearchRequested event, Emitter<PublicProfileState> emit) async {
    final UserRelationKind kind = event.kind;
    _latestQuery[kind] = event.query;
    _emitRelation(kind, emit, (list) => list.copyWith(isSearching: true, searchResults: const <UserSummaryEntity>[]));
    final result = await _searchUsersByUsernameUseCase(
      SearchUsersByUsernameParams(query: event.query, scopeEmails: event.allEmails),
    );
    if (event.query != _latestQuery[kind]) return;
    final List<UserSummaryEntity> summaries = result.data ?? const <UserSummaryEntity>[];
    _emitRelation(kind, emit, (list) => list.copyWith(isSearching: false, searchResults: summaries));
  }

  void _onRelationSearchCleared(_RelationSearchCleared event, Emitter<PublicProfileState> emit) {
    _latestQuery[event.kind] = '';
    _emitRelation(event.kind, emit, (list) => list.copyWith(searchResults: null, isSearching: false));
  }

  Future<void> _onFollowChangeRequested(_FollowChangeRequested event, Emitter<PublicProfileState> emit) async {
    final String targetKey = event.targetUserEmail.trim().toLowerCase();
    emit(_withFollowApplied(state, event.targetUserEmail, follow: event.follow));

    final result = event.follow
        ? await _followUserUseCase(
            FollowUserParams(
              currentUserId: event.currentUserId,
              currentUserEmail: event.currentUserEmail,
              targetUserId: event.targetUserId,
              targetUserEmail: event.targetUserEmail,
            ),
          )
        : await _unfollowUserUseCase(
            UnfollowUserParams(
              currentUserId: event.currentUserId,
              currentUserEmail: event.currentUserEmail,
              targetUserId: event.targetUserId,
              targetUserEmail: event.targetUserEmail,
            ),
          );
    final FollowOutcome outcome = FollowOutcome(
      id: (state.followOutcome?.id ?? 0) + 1,
      follow: event.follow,
      success: result.isSuccess,
      targetName: event.targetName,
    );
    if (result.isFailure) {
      final PublicProfileState rolledBack = _withFollowApplied(state, event.targetUserEmail, follow: !event.follow);
      emit(
        rolledBack.copyWith(
          followOverrides: <String, bool>{...rolledBack.followOverrides}..remove(targetKey),
          followOutcome: outcome,
        ),
      );
      return;
    }

    await _syncSessionFollowing(event.targetUserEmail, follow: event.follow);
    unawaited(_syncPostsTopic(event.targetUserEmail, follow: event.follow));
    emit(state.copyWith(followOutcome: outcome));
  }

  /// Posts pushes for the creator follow the follow state.
  Future<void> _syncPostsTopic(String email, {required bool follow}) async {
    try {
      if (follow && !creatorPostsAlertsEnabled) return;
      await setCreatorPostsTopics(
        FirebaseMessaging.instance,
        <String>[email],
        subscribed: follow,
        sourceTag: follow ? 'follow.subscribe_posts_topic' : 'unfollow.unsubscribe_posts_topic',
      );
    } catch (error, stackTrace) {
      logger.w('Could not sync the posts topic.', error: error, stackTrace: stackTrace);
    }
  }

  PublicProfileState _withFollowApplied(PublicProfileState from, String email, {required bool follow}) {
    return from.copyWith(
      followOverrides: <String, bool>{...from.followOverrides, email.trim().toLowerCase(): follow},
      followers: from.followers.withFollowState(email, isFollowed: follow),
      following: from.following.withFollowState(email, isFollowed: follow),
    );
  }

  Future<void> _syncSessionFollowing(String email, {required bool follow}) async {
    final String key = email.trim().toLowerCase();
    final List<String> next = app_state.prismUser.following
        .where((String e) => e.trim().toLowerCase() != key)
        .toList(growable: true);
    if (follow) next.add(email);
    app_state.prismUser.following = next;
    await app_state.persistPrismUser();
  }
}
