import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
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

  int _wallGeneration = 0;
  bool _isClosing = false;
  // Only the newest search may write results; slower earlier ones are dropped.
  final Map<UserRelationKind, String> _latestQuery = <UserRelationKind, String>{};
  final Map<String, Future<void>> _followTails = <String, Future<void>>{};
  final Map<String, Object> _followIntents = <String, Object>{};
  final Map<String, bool> _confirmedFollowing = <String, bool>{};
  final Map<String, bool> _baselineFollowing = <String, bool>{};

  final FetchPublicProfileWallsUseCase _fetchPublicProfileWallsUseCase;
  final FollowUserUseCase _followUserUseCase;
  final UnfollowUserUseCase _unfollowUserUseCase;
  final FetchUserSummariesPageUseCase _fetchUserSummariesPageUseCase;
  final SearchUsersByUsernameUseCase _searchUsersByUsernameUseCase;

  @override
  Future<void> close() {
    _isClosing = true;
    return super.close();
  }

  Future<void> _onStarted(_Started event, Emitter<PublicProfileState> emit) async {
    // Clear previous user's walls immediately so UI never flashes stale grids.
    emit(
      state.copyWith(
        profileId: event.identifier,
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
    final int generation = ++_wallGeneration;
    final String userId = state.profileId;
    if (state.profileId.isEmpty) {
      emit(state.copyWith(status: LoadStatus.failure));
      return;
    }

    emit(state.copyWith(status: LoadStatus.loading, isFetchingMoreWalls: false));

    final wallsResult = await _fetchPublicProfileWallsUseCase(
      FetchPublicProfileWallsParams(userId: userId, refresh: refresh),
    );
    if (_isClosing || isClosed || emit.isDone || generation != _wallGeneration) return;

    wallsResult.fold(
      onSuccess: (walls) => emit(
        state.copyWith(
          status: LoadStatus.success,
          walls: walls.items,
          hasMoreWalls: walls.hasMore,
          isFetchingMoreWalls: false,
        ),
      ),
      onFailure: (_) => emit(state.copyWith(status: LoadStatus.failure, isFetchingMoreWalls: false)),
    );
  }

  Future<void> _onFetchMoreWallsRequested(_FetchMoreWallsRequested event, Emitter<PublicProfileState> emit) async {
    if (state.profileId.isEmpty ||
        state.status == LoadStatus.loading ||
        state.isFetchingMoreWalls ||
        !state.hasMoreWalls) {
      return;
    }
    final int generation = _wallGeneration;
    final String userId = state.profileId;
    emit(state.copyWith(isFetchingMoreWalls: true));

    final result = await _fetchPublicProfileWallsUseCase(FetchPublicProfileWallsParams(userId: userId, refresh: false));
    if (_isClosing || isClosed || emit.isDone || generation != _wallGeneration) return;

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
      FetchUserSummariesPageParams(userIds: event.userIds, page: event.page),
    );

    result.fold(
      onSuccess: (page) {
        final merged = event.page == 0
            ? page.items
            : <UserSummaryEntity>[...state.relation(kind).summaries, ...page.items];
        final deduped = <String, UserSummaryEntity>{for (final s in merged) s.id: s}.values.toList(growable: false);
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
      SearchUsersByUsernameParams(query: event.query, scopeUserIds: event.userIds),
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
    final int session = CoinsService.instance.economySession;
    bool ownsSession() =>
        !_isClosing &&
        !isClosed &&
        !emit.isDone &&
        session == CoinsService.instance.economySession &&
        app_state.prismUser.loggedIn &&
        app_state.prismUser.id == event.currentUserId &&
        app_state.prismUser.email.trim().toLowerCase() == event.currentUserEmail.trim().toLowerCase();
    if (!ownsSession()) return;
    final String targetKey = event.targetUserId.trim();
    if (targetKey.isEmpty) return;
    final String queueKey = '${event.currentUserId}::$targetKey';
    final String operationKey = '$session::$queueKey';
    if (!_confirmedFollowing.containsKey(operationKey) && !_baselineFollowing.containsKey(operationKey)) {
      final bool? listed = _relationFollowState(state, targetKey);
      if (listed != null) _baselineFollowing[operationKey] = listed;
    }
    final Object intent = Object();
    _followIntents[targetKey] = intent;
    // A returning owner's new intent must still follow any already-dispatched transaction.
    final Future<void>? previous = _followTails[queueKey];
    final completion = Completer<void>();
    _followTails[queueKey] = completion.future;
    emit(_withFollowApplied(state, targetKey, follow: event.follow));

    try {
      if (previous != null) await previous;
      if (!ownsSession()) return;
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
      if (!ownsSession()) return;
      final bool ownsIntent = identical(_followIntents[targetKey], intent);
      final FollowOutcome outcome = FollowOutcome(
        id: (state.followOutcome?.id ?? 0) + 1,
        follow: event.follow,
        success: result.isSuccess,
        targetName: event.targetName,
      );
      unawaited(
        analytics.track(
          FollowResultEvent(
            action: event.follow ? 'follow' : 'unfollow',
            result: result.isSuccess ? 'success' : 'failure',
            creatorId: event.targetUserId,
            source: 'public_profile',
          ),
        ),
      );
      if (result.isFailure) {
        if (!ownsIntent) return;
        final bool? confirmed = _confirmedFollowing[operationKey];
        final bool? actual = confirmed ?? _baselineFollowing[operationKey];
        final PublicProfileState rolledBack = actual == null
            ? state
            : _withFollowApplied(state, targetKey, follow: actual);
        final overrides = <String, bool>{...rolledBack.followOverrides};
        if (confirmed != null) {
          overrides[targetKey] = confirmed;
        } else {
          overrides.remove(targetKey);
        }
        emit(rolledBack.copyWith(followOverrides: overrides, followOutcome: outcome));
        return;
      }

      _confirmedFollowing[operationKey] = event.follow;
      await _syncPostsTopic(event.targetUserId, follow: event.follow, isCurrent: ownsSession);
      if (!ownsSession() || !identical(_followIntents[targetKey], intent)) return;
      emit(state.copyWith(followOutcome: outcome.copyWith(id: (state.followOutcome?.id ?? 0) + 1)));
    } finally {
      completion.complete();
      if (identical(_followTails[queueKey], completion.future)) _followTails.remove(queueKey);
      if (identical(_followIntents[targetKey], intent)) _followIntents.remove(targetKey);
    }
  }

  /// Posts pushes for the creator follow the follow state.
  Future<void> _syncPostsTopic(String targetUserId, {required bool follow, required bool Function() isCurrent}) async {
    try {
      if (follow && !creatorPostsAlertsEnabled) return;
      await setCreatorPostsTopicForUid(
        FirebaseMessaging.instance,
        targetUserId,
        subscribed: follow,
        sourceTag: follow ? 'follow.subscribe_posts_topic' : 'unfollow.unsubscribe_posts_topic',
        isCurrent: isCurrent,
      );
    } catch (error, stackTrace) {
      logger.w('Could not sync the posts topic.', error: error, stackTrace: stackTrace);
    }
  }

  PublicProfileState _withFollowApplied(PublicProfileState from, String userId, {required bool follow}) {
    return from.copyWith(
      followOverrides: <String, bool>{...from.followOverrides, userId: follow},
      followers: from.followers.withFollowState(userId, isFollowed: follow),
      following: from.following.withFollowState(userId, isFollowed: follow),
    );
  }

  bool? _relationFollowState(PublicProfileState from, String userId) {
    for (final UserSummaryEntity user in <UserSummaryEntity>[
      ...from.followers.summaries,
      ...from.following.summaries,
      ...?from.followers.searchResults,
      ...?from.following.searchResults,
    ]) {
      if (user.id == userId) return user.isFollowedByCurrentUser;
    }
    return null;
  }
}
