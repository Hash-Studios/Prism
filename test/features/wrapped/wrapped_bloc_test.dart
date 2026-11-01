import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/wrapped/biz/bloc/wrapped_bloc.j.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_user_fixture.dart';
import 'wrapped_fixture.dart';

class _Repository implements WrappedRepository {
  final Map<String, Completer<WrappedYear?>> pending = <String, Completer<WrappedYear?>>{};

  @override
  Future<WrappedYear?> fetch(String uid, int year) => (pending[uid] ??= Completer<WrappedYear?>()).future;
}

class _Sessions implements SessionRepository {
  _Sessions(this.currentUser);

  final StreamController<PrismUsersV2> _users = StreamController<PrismUsersV2>.broadcast(sync: true);
  @override
  PrismUsersV2 currentUser;

  @override
  Stream<PrismUsersV2> watchCurrentUser() async* {
    yield currentUser;
    yield* _users.stream;
  }

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user) async {
    currentUser = user;
    _users.add(user);
    return Result.success<SessionEntity>(
      SessionEntity(
        userId: user.id,
        loggedIn: user.loggedIn,
        premium: user.premium,
        subscriptionTier: user.subscriptionTier,
      ),
    );
  }

  @override
  Future<Result<SessionEntity>> getSession() => throw UnimplementedError();

  @override
  Future<Result<SessionEntity>> updateFollowing(List<String> following) => throw UnimplementedError();

  Future<void> close() => _users.close();
}

void main() {
  test('clears the cached Wrapped when the session has no signed-in uid', () async {
    final _Repository repository = _Repository();
    final WrappedBloc bloc = WrappedBloc(repository);
    addTearDown(bloc.close);
    repository.pending['user-a'] = Completer<WrappedYear?>()..complete(fixtureWrappedYear());

    bloc.add(const WrappedEvent.load('user-a'));
    await expectLater(bloc.stream, emitsInOrder(<Matcher>[isA<WrappedLoading>(), isA<WrappedReady>()]));

    bloc.add(const WrappedEvent.load(''));
    await expectLater(bloc.stream, emits(const WrappedState.idle()));
  });

  test('a previous account fetch cannot replace the current account state', () async {
    final _Repository repository = _Repository();
    final WrappedBloc bloc = WrappedBloc(repository);
    final List<WrappedState> states = <WrappedState>[];
    final StreamSubscription<WrappedState> subscription = bloc.stream.listen(states.add);
    addTearDown(() async {
      await subscription.cancel();
      await bloc.close();
    });

    bloc.add(const WrappedEvent.load('user-a'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const WrappedEvent.load('user-b'));
    await Future<void>.delayed(Duration.zero);
    repository.pending['user-a']!.complete(fixtureWrappedYear());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const WrappedState.loading('user-b'));

    repository.pending['user-b']!.complete(null);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, const WrappedState.notEligible('user-b'));
    expect(states.whereType<WrappedReady>(), isEmpty);
  });

  test('session changes clear cached Wrapped even when no view requests a reload', () async {
    final PrismUsersV2 userA = profileUser(id: 'user-a');
    final _Sessions sessions = _Sessions(userA);
    getIt.registerSingleton<SessionRepository>(sessions);
    final _Repository repository = _Repository();
    repository.pending['user-a'] = Completer<WrappedYear?>()..complete(fixtureWrappedYear());
    final WrappedBloc bloc = WrappedBloc(repository);
    final List<String> userChanges = <String>[];
    final StreamSubscription<String> userSubscription = bloc.userChanges.listen(userChanges.add);
    addTearDown(() async {
      await userSubscription.cancel();
      await bloc.close();
      if (getIt.isRegistered<SessionRepository>()) await getIt.unregister<SessionRepository>();
      await sessions.close();
    });

    bloc.add(const WrappedEvent.load('user-a'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, isA<WrappedReady>());

    await sessions.replaceCurrentUser(profileUser(id: 'user-b'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, const WrappedState.idle());
    expect(userChanges, <String>['user-b']);
  });
}
