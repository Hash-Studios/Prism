import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SessionRepository)
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._sessionLocal) {
    _currentUser = _readStoredUser();
  }

  final SessionLocalDataSource _sessionLocal;
  final StreamController<PrismUsersV2> _currentUserController = StreamController<PrismUsersV2>.broadcast();

  late PrismUsersV2 _currentUser;

  @override
  PrismUsersV2 get currentUser => _currentUser;

  @override
  Stream<PrismUsersV2> watchCurrentUser() async* {
    yield _currentUser;
    yield* _currentUserController.stream;
  }

  PrismUsersV2 _readStoredUser() {
    return _sessionLocal.readCurrentUser();
  }

  Future<void> _persistCurrentUser() async {
    await _sessionLocal.writeCurrentUser(_currentUser);
  }

  void _emitCurrentUser() {
    if (_currentUserController.isClosed) {
      return;
    }
    _currentUserController.add(_currentUser);
  }

  SessionEntity _toEntity() {
    return SessionEntity(
      userId: _currentUser.id,
      loggedIn: _currentUser.loggedIn,
      premium: _currentUser.premium,
      subscriptionTier: _currentUser.subscriptionTier,
    );
  }

  @override
  Future<Result<SessionEntity>> getSession() async {
    try {
      // Read without emitting: an emit here would make SessionBloc's stream listener re-dispatch started in a loop.
      _currentUser = _readStoredUser();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(CacheFailure('Unable to read session: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user) async {
    try {
      _currentUser = user;
      await _persistCurrentUser();
      _emitCurrentUser();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(CacheFailure('Unable to replace session: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> updateFollowing(List<String> following) async {
    try {
      _currentUser.following = following;
      await _persistCurrentUser();
      _emitCurrentUser();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(CacheFailure('Unable to update following: $error'));
    }
  }
}
