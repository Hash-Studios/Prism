import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/user_search/biz/bloc/user_search_bloc.j.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/domain/usecases/search_users_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSearchUsers extends Mock implements SearchUsersUseCase {}

UserSearchUser _user(String name) => UserSearchUser(
  id: name,
  name: name,
  username: name.toLowerCase(),
  email: '$name@example.com',
  profilePhoto: '',
  followerCount: 0,
);

void main() {
  late _MockSearchUsers search;
  late UserSearchBloc bloc;
  final Map<String, Completer<Result<List<UserSearchUser>>>> pending =
      <String, Completer<Result<List<UserSearchUser>>>>{};

  setUpAll(() => registerFallbackValue(const SearchUsersParams(query: '')));

  setUp(() {
    pending.clear();
    search = _MockSearchUsers();
    when(() => search(any())).thenAnswer((invocation) {
      final String query = (invocation.positionalArguments.single as SearchUsersParams).query;
      return (pending[query] = Completer<Result<List<UserSearchUser>>>()).future;
    });
    bloc = UserSearchBloc(search);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a slow answer for an older query never replaces the answer for the newest query', () async {
    bloc.add(const UserSearchEvent.searchRequested(query: 'jo'));
    await settle();
    bloc.add(const UserSearchEvent.searchRequested(query: 'john'));
    await settle();

    pending['john']!.complete(Result.success(<UserSearchUser>[_user('John')]));
    await settle();
    pending['jo']!.complete(Result.success(<UserSearchUser>[_user('Joe'), _user('John')]));
    await settle();

    expect(bloc.state.query, 'john');
    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.users.map((u) => u.name), <String>['John']);
  });

  test('a late failure of an older query cannot hide the newest results', () async {
    bloc.add(const UserSearchEvent.searchRequested(query: 'jo'));
    await settle();
    bloc.add(const UserSearchEvent.searchRequested(query: 'john'));
    await settle();

    pending['john']!.complete(Result.success(<UserSearchUser>[_user('John')]));
    await settle();
    pending['jo']!.complete(Result.error(const ServerFailure('offline')));
    await settle();

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.failure, isNull);
  });

  test('clearing the field drops an answer that was still on its way', () async {
    bloc.add(const UserSearchEvent.searchRequested(query: 'jo'));
    await settle();
    bloc.add(const UserSearchEvent.cleared());
    await settle();

    pending['jo']!.complete(Result.success(<UserSearchUser>[_user('Joe')]));
    await settle();

    expect(bloc.state.status, LoadStatus.initial);
    expect(bloc.state.users, isEmpty);
  });
}
