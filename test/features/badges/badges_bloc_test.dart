import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements BadgeRepository {
  Result<List<Badge>> next = Result.success(<Badge>[]);

  @override
  ValueListenable<List<EarnedBadge>> get unseen => ValueNotifier<List<EarnedBadge>>(const <EarnedBadge>[]);

  @override
  Future<Result<List<Badge>>> check() async => next;

  @override
  void markSeen(String id) {}
}

Badge _b(String id) => Badge(name: id, description: '', id: id, awardedAt: '', imageUrl: '', color: '', url: '');

void main() {
  late _FakeRepo repo;

  setUp(() {
    repo = _FakeRepo();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  blocTest<BadgesBloc, BadgesState>(
    'loads from the session first, then the server result',
    build: () {
      app_state.prismUser.badges = <Badge>[_b('collector')];
      repo.next = Result.success(<Badge>[_b('collector'), _b('creator')]);
      return BadgesBloc(repo);
    },
    act: (bloc) => bloc.add(const BadgesLoaded()),
    expect: () => <BadgesState>[
      const BadgesState(status: BadgesStatus.loading, earnedIds: <String>['collector']),
      const BadgesState(status: BadgesStatus.success, earnedIds: <String>['collector', 'creator']),
    ],
  );

  blocTest<BadgesBloc, BadgesState>(
    'a failed check keeps the badges the session already has',
    build: () {
      app_state.prismUser.badges = <Badge>[_b('collector')];
      repo.next = Result.error(const ServerFailure('nope'));
      return BadgesBloc(repo);
    },
    act: (bloc) => bloc.add(const BadgesLoaded()),
    expect: () => <BadgesState>[
      const BadgesState(status: BadgesStatus.loading, earnedIds: <String>['collector']),
      const BadgesState(status: BadgesStatus.failure, earnedIds: <String>['collector']),
    ],
  );
}
