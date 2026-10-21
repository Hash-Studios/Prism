import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
import 'package:Prism/features/session/data/repositories/session_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

class _SessionStore extends SessionLocalDataSource {
  _SessionStore() : super(InMemoryLocalStore());

  bool failRead = false;
  bool failWrite = false;

  @override
  PrismUsersV2 readCurrentUser() {
    if (failRead) throw StateError('disk read failed');
    return super.readCurrentUser();
  }

  @override
  Future<void> writeCurrentUser(PrismUsersV2 user) async {
    if (failWrite) throw StateError('disk write failed');
    await super.writeCurrentUser(user);
  }
}

void main() {
  test('replacement and following edits survive a fresh repository and notify subscribers', () async {
    final local = _SessionStore();
    final repository = SessionRepositoryImpl(local);
    final observed = <String>[];
    final subscription = repository.watchCurrentUser().listen((user) => observed.add(user.id));
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    final user = createGuestPrismUser()
      ..id = 'creator-7'
      ..loggedIn = true
      ..premium = true
      ..subscriptionTier = 'pro';

    final replacement = await repository.replaceCurrentUser(user);
    final update = await repository.updateFollowing(<String>['artist-1', 'artist-2']);
    await pumpEventQueue();

    expect(replacement.data?.userId, 'creator-7');
    expect(replacement.data?.loggedIn, isTrue);
    expect(replacement.data?.premium, isTrue);
    expect(replacement.data?.subscriptionTier, 'pro');
    expect(update.data?.userId, 'creator-7');
    expect(observed.last, 'creator-7');
    expect(observed.length, 3);
    expect(SessionRepositoryImpl(local).currentUser.following, <String>['artist-1', 'artist-2']);
  });

  test('reading a changed stored session refreshes the result without broadcasting another change', () async {
    final local = _SessionStore();
    final initial = createGuestPrismUser()..id = 'before';
    await local.writeCurrentUser(initial);
    final repository = SessionRepositoryImpl(local);
    final observed = <String>[];
    final subscription = repository.watchCurrentUser().listen((user) => observed.add(user.id));
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    await local.writeCurrentUser(createGuestPrismUser()..id = 'after');

    final result = await repository.getSession();
    await pumpEventQueue();

    expect(result.data?.userId, 'after');
    expect(repository.currentUser.id, 'after');
    expect(observed, <String>['before']);
  });

  test('storage failures become actionable cache failures for each operation', () async {
    final local = _SessionStore();
    final repository = SessionRepositoryImpl(local);
    local.failRead = true;
    final read = await repository.getSession();
    expect(read.failure, isA<CacheFailure>());
    expect(read.failure?.message, 'Unable to read session: Bad state: disk read failed');

    local.failWrite = true;
    final replace = await repository.replaceCurrentUser(createGuestPrismUser());
    expect(replace.failure, isA<CacheFailure>());
    expect(replace.failure?.message, 'Unable to replace session: Bad state: disk write failed');
    final update = await repository.updateFollowing(<String>['artist']);
    expect(update.failure, isA<CacheFailure>());
    expect(update.failure?.message, 'Unable to update following: Bad state: disk write failed');
  });
}
