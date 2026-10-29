import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/features/wall_requests/biz/wall_request_sheet_cubit.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/domain/repositories/wall_requests_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';

class _MockRepository extends Mock implements WallRequestsRepository {}

WallRequest _request({String id = 'r1', bool mine = false, bool voted = false, int voteCount = 3}) => WallRequest(
  id: id,
  text: 'Neon tokyo street',
  tags: const <String>['Neon'],
  voteCount: voteCount,
  status: WallRequestStatus.open,
  createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
  requesterName: 'Ana',
  requesterPhoto: '',
  mine: mine,
  voted: voted,
  hidden: false,
);

void main() {
  late _MockRepository repository;
  late FakeAppAnalytics analytics;

  setUp(() {
    repository = _MockRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
  });

  Future<void> submitNeon(WallRequestSheetCubit cubit) =>
      cubit.submit(text: 'Neon tokyo', tags: <String>['Neon'], source: WallRequestSourceValue.search);

  void stubDuplicate({bool exact = true, bool mine = false, bool voted = false}) {
    when(() => repository.create(text: 'Neon tokyo', tags: <String>['Neon'])).thenAnswer(
      (_) async => WallRequestDuplicate(
        _request(mine: mine, voted: voted),
        exact: exact,
      ),
    );
  }

  group('submit', () {
    blocTest<WallRequestSheetCubit, WallRequestSheetState>(
      'created emits busy then done without an upvote and tracks the create',
      build: () {
        when(
          () => repository.create(text: 'Neon tokyo', tags: <String>['Neon']),
        ).thenAnswer((_) async => WallRequestCreated(_request()));
        return WallRequestSheetCubit(repository);
      },
      act: submitNeon,
      expect: () => <Matcher>[
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDone>()
            .having((WallRequestSheetDone s) => s.upvoted, 'upvoted', isFalse)
            .having((WallRequestSheetDone s) => s.request.id, 'request id', 'r1'),
      ],
      verify: (_) async {
        await Future<void>.delayed(Duration.zero);
        expect(
          analytics.events.single,
          isA<WallRequestCreatedEvent>()
              .having((WallRequestCreatedEvent e) => e.source, 'source', WallRequestSourceValue.search)
              .having((WallRequestCreatedEvent e) => e.tagCount, 'tagCount', 1)
              .having((WallRequestCreatedEvent e) => e.forced, 'forced', isFalse),
        );
      },
    );

    blocTest<WallRequestSheetCubit, WallRequestSheetState>(
      'duplicate emits the duplicate with its exact flag',
      build: () {
        stubDuplicate();
        return WallRequestSheetCubit(repository);
      },
      act: submitNeon,
      expect: () => <Matcher>[
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDuplicate>()
            .having((WallRequestSheetDuplicate s) => s.exact, 'exact', isTrue)
            .having((WallRequestSheetDuplicate s) => s.request.id, 'request id', 'r1')
            .having((WallRequestSheetDuplicate s) => s.error, 'error', isNull),
      ],
    );

    blocTest<WallRequestSheetCubit, WallRequestSheetState>(
      'a failed submit returns to editing with the error',
      build: () {
        when(
          () => repository.create(text: 'Neon tokyo', tags: <String>['Neon']),
        ).thenThrow(const WallRequestException(WallRequestError.dailyLimit));
        return WallRequestSheetCubit(repository);
      },
      act: submitNeon,
      expect: () => <Matcher>[
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetEditing>().having(
          (WallRequestSheetEditing s) => s.error,
          'error',
          WallRequestError.dailyLimit,
        ),
      ],
    );
  });

  group('upvoteInstead', () {
    blocTest<WallRequestSheetCubit, WallRequestSheetState>(
      'busy then done upvoted with the server count and tracks the upvote',
      build: () {
        stubDuplicate();
        when(() => repository.setVote('r1', vote: true)).thenAnswer((_) async => 9);
        return WallRequestSheetCubit(repository);
      },
      act: (WallRequestSheetCubit cubit) async {
        await submitNeon(cubit);
        await cubit.upvoteInstead();
      },
      expect: () => <Matcher>[
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDuplicate>(),
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDone>()
            .having((WallRequestSheetDone s) => s.upvoted, 'upvoted', isTrue)
            .having((WallRequestSheetDone s) => s.request.voted, 'voted', isTrue)
            .having((WallRequestSheetDone s) => s.request.voteCount, 'voteCount', 9),
      ],
      verify: (_) async {
        await Future<void>.delayed(Duration.zero);
        expect(analytics.events.whereType<WallRequestDuplicateUpvotedEvent>().single.exact, isTrue);
      },
    );

    blocTest<WallRequestSheetCubit, WallRequestSheetState>(
      'an already voted duplicate goes straight to done without a vote call',
      build: () {
        stubDuplicate(voted: true);
        return WallRequestSheetCubit(repository);
      },
      act: (WallRequestSheetCubit cubit) async {
        await submitNeon(cubit);
        await cubit.upvoteInstead();
      },
      expect: () => <Matcher>[
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDuplicate>(),
        isA<WallRequestSheetDone>().having((WallRequestSheetDone s) => s.upvoted, 'upvoted', isTrue),
      ],
      verify: (_) {
        verifyNever(() => repository.setVote(any(), vote: any(named: 'vote')));
      },
    );

    blocTest<WallRequestSheetCubit, WallRequestSheetState>(
      'an own duplicate goes straight to done without a vote call',
      build: () {
        stubDuplicate(mine: true);
        return WallRequestSheetCubit(repository);
      },
      act: (WallRequestSheetCubit cubit) async {
        await submitNeon(cubit);
        await cubit.upvoteInstead();
      },
      expect: () => <Matcher>[
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDuplicate>(),
        isA<WallRequestSheetDone>().having((WallRequestSheetDone s) => s.upvoted, 'upvoted', isFalse),
      ],
      verify: (_) {
        verifyNever(() => repository.setVote(any(), vote: any(named: 'vote')));
      },
    );

    blocTest<WallRequestSheetCubit, WallRequestSheetState>(
      'a failed upvote returns to the duplicate with the error',
      build: () {
        stubDuplicate(exact: false);
        when(() => repository.setVote('r1', vote: true)).thenThrow(const WallRequestException(WallRequestError.closed));
        return WallRequestSheetCubit(repository);
      },
      act: (WallRequestSheetCubit cubit) async {
        await submitNeon(cubit);
        await cubit.upvoteInstead();
      },
      expect: () => <Matcher>[
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDuplicate>(),
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDuplicate>()
            .having((WallRequestSheetDuplicate s) => s.exact, 'exact', isFalse)
            .having((WallRequestSheetDuplicate s) => s.error, 'error', WallRequestError.closed),
      ],
    );
  });

  group('edit', () {
    blocTest<WallRequestSheetCubit, WallRequestSheetState>(
      'returns from the duplicate card to editing',
      build: () {
        stubDuplicate();
        return WallRequestSheetCubit(repository);
      },
      act: (WallRequestSheetCubit cubit) async {
        await submitNeon(cubit);
        cubit.edit();
      },
      expect: () => <Matcher>[
        isA<WallRequestSheetBusy>(),
        isA<WallRequestSheetDuplicate>(),
        isA<WallRequestSheetEditing>().having((WallRequestSheetEditing s) => s.error, 'error', isNull),
      ],
    );
  });
}
