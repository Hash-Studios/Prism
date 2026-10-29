import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/features/wall_requests/biz/wall_requests_cubit.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/domain/repositories/wall_requests_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';

class _MockRepository extends Mock implements WallRequestsRepository {}

WallRequest _request({
  String id = 'r1',
  bool mine = false,
  bool voted = false,
  int voteCount = 3,
  WallRequestStatus status = WallRequestStatus.open,
  bool hidden = false,
}) => WallRequest(
  id: id,
  text: 'Neon tokyo street',
  tags: const <String>['Neon'],
  voteCount: voteCount,
  status: status,
  createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
  requesterName: 'Ana',
  requesterPhoto: '',
  mine: mine,
  voted: voted,
  hidden: hidden,
);

WallRequestsTabState _tab(WallRequestsState state, WallRequestTab tab) => state.tab(tab);

List<String> _ids(WallRequestsState state, WallRequestTab tab) {
  final WallRequestsTabState value = _tab(state, tab);
  return value is WallRequestsTabLoaded ? value.requests.map((WallRequest r) => r.id).toList() : <String>[];
}

WallRequest _row(WallRequestsState state, WallRequestTab tab, String id) =>
    (_tab(state, tab) as WallRequestsTabLoaded).requests.firstWhere((WallRequest r) => r.id == id);

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

  Future<void> flushAnalytics() => Future<void>.delayed(Duration.zero);

  group('load', () {
    blocTest<WallRequestsCubit, WallRequestsState>(
      'emits loading then loaded with the list',
      build: () {
        when(() => repository.list(WallRequestTab.top)).thenAnswer((_) async => <WallRequest>[_request()]);
        return WallRequestsCubit(repository);
      },
      act: (WallRequestsCubit cubit) => cubit.load(WallRequestTab.top),
      expect: () => <Matcher>[
        isA<WallRequestsState>().having(
          (WallRequestsState s) => _tab(s, WallRequestTab.top),
          'top',
          isA<WallRequestsTabLoading>(),
        ),
        isA<WallRequestsState>().having((WallRequestsState s) => _ids(s, WallRequestTab.top), 'top ids', <String>[
          'r1',
        ]),
      ],
    );

    blocTest<WallRequestsCubit, WallRequestsState>(
      'a failed load emits failed for that tab',
      build: () {
        when(() => repository.list(WallRequestTab.top)).thenThrow(const WallRequestException(WallRequestError.unknown));
        return WallRequestsCubit(repository);
      },
      act: (WallRequestsCubit cubit) => cubit.load(WallRequestTab.top),
      expect: () => <Matcher>[
        isA<WallRequestsState>(),
        isA<WallRequestsState>().having(
          (WallRequestsState s) => _tab(s, WallRequestTab.top),
          'top',
          isA<WallRequestsTabFailed>(),
        ),
      ],
    );

    test('a later load result wins over an earlier slow one', () async {
      final Completer<List<WallRequest>> first = Completer<List<WallRequest>>();
      final Completer<List<WallRequest>> second = Completer<List<WallRequest>>();
      final WallRequestsCubit cubit = WallRequestsCubit(repository);
      addTearDown(cubit.close);

      when(() => repository.list(WallRequestTab.top)).thenAnswer((_) => first.future);
      final Future<void> firstLoad = cubit.load(WallRequestTab.top);
      when(() => repository.list(WallRequestTab.top)).thenAnswer((_) => second.future);
      final Future<void> secondLoad = cubit.load(WallRequestTab.top);

      second.complete(<WallRequest>[_request(id: 'b')]);
      await secondLoad;
      first.complete(<WallRequest>[_request(id: 'a')]);
      await firstLoad;

      expect(_ids(cubit.state, WallRequestTab.top), <String>['b']);
    });
  });

  group('toggleVote', () {
    test('flips voted and count at once, then sets the server count and tracks the vote', () async {
      final Completer<int> server = Completer<int>();
      when(() => repository.list(WallRequestTab.top)).thenAnswer((_) async => <WallRequest>[_request()]);
      when(() => repository.setVote('r1', vote: true)).thenAnswer((_) => server.future);
      final WallRequestsCubit cubit = WallRequestsCubit(repository);
      addTearDown(cubit.close);
      await cubit.load(WallRequestTab.top);

      final Future<void> toggle = cubit.toggleVote(_request(), WallRequestTab.top);
      final WallRequest optimistic = _row(cubit.state, WallRequestTab.top, 'r1');
      expect(optimistic.voted, isTrue);
      expect(optimistic.voteCount, 4);

      server.complete(9);
      await toggle;

      final WallRequest settled = _row(cubit.state, WallRequestTab.top, 'r1');
      expect(settled.voted, isTrue);
      expect(settled.voteCount, 9);
      await flushAnalytics();
      expect(
        analytics.events.single,
        isA<WallRequestVoteToggledEvent>()
            .having((WallRequestVoteToggledEvent e) => e.voted, 'voted', isTrue)
            .having((WallRequestVoteToggledEvent e) => e.tab, 'tab', 'top'),
      );
    });

    test('an ownRequest failure rolls the row back and sets the error', () async {
      when(() => repository.list(WallRequestTab.top)).thenAnswer((_) async => <WallRequest>[_request()]);
      when(
        () => repository.setVote('r1', vote: true),
      ).thenThrow(const WallRequestException(WallRequestError.ownRequest));
      final WallRequestsCubit cubit = WallRequestsCubit(repository);
      addTearDown(cubit.close);
      await cubit.load(WallRequestTab.top);

      await cubit.toggleVote(_request(), WallRequestTab.top);

      final WallRequest row = _row(cubit.state, WallRequestTab.top, 'r1');
      expect(row.voted, isFalse);
      expect(row.voteCount, 3);
      expect(cubit.state.error, WallRequestError.ownRequest);
      await flushAnalytics();
      expect(analytics.events.whereType<WallRequestVoteToggledEvent>(), isEmpty);
    });

    test('clearError clears the error and keeps the tabs', () async {
      when(() => repository.list(WallRequestTab.top)).thenAnswer((_) async => <WallRequest>[_request()]);
      when(
        () => repository.setVote('r1', vote: true),
      ).thenThrow(const WallRequestException(WallRequestError.ownRequest));
      final WallRequestsCubit cubit = WallRequestsCubit(repository);
      addTearDown(cubit.close);
      await cubit.load(WallRequestTab.top);
      await cubit.toggleVote(_request(), WallRequestTab.top);

      cubit.clearError();

      expect(cubit.state.error, isNull);
      expect(_ids(cubit.state, WallRequestTab.top), <String>['r1']);
    });

    test('does nothing for own, filled or hidden requests', () async {
      final WallRequestsCubit cubit = WallRequestsCubit(repository);
      addTearDown(cubit.close);
      final List<WallRequest> blocked = <WallRequest>[
        _request(mine: true),
        _request(id: 'f', status: WallRequestStatus.filled),
        _request(id: 'h', hidden: true),
      ];

      for (final WallRequest request in blocked) {
        await cubit.toggleVote(request, WallRequestTab.top);
      }

      verifyNever(() => repository.setVote(any(), vote: any(named: 'vote')));
      expect(cubit.state.error, isNull);
    });

    test('a request in Top and New updates in both tabs', () async {
      when(() => repository.list(WallRequestTab.top)).thenAnswer((_) async => <WallRequest>[_request()]);
      when(() => repository.list(WallRequestTab.newest)).thenAnswer((_) async => <WallRequest>[_request()]);
      when(() => repository.setVote('r1', vote: true)).thenAnswer((_) async => 4);
      final WallRequestsCubit cubit = WallRequestsCubit(repository);
      addTearDown(cubit.close);
      await cubit.load(WallRequestTab.top);
      await cubit.load(WallRequestTab.newest);

      await cubit.toggleVote(_request(), WallRequestTab.top);

      for (final WallRequestTab tab in <WallRequestTab>[WallRequestTab.top, WallRequestTab.newest]) {
        final WallRequest row = _row(cubit.state, tab, 'r1');
        expect(row.voted, isTrue, reason: tab.name);
        expect(row.voteCount, 4, reason: tab.name);
      }
    });
  });

  group('setHidden', () {
    test('marks the request hidden after the server accepts', () async {
      when(() => repository.list(WallRequestTab.top)).thenAnswer((_) async => <WallRequest>[_request()]);
      when(() => repository.setHidden('r1', hidden: true)).thenAnswer((_) async {});
      final WallRequestsCubit cubit = WallRequestsCubit(repository);
      addTearDown(cubit.close);
      await cubit.load(WallRequestTab.top);

      await cubit.setHidden(_request(), hidden: true);

      expect(_row(cubit.state, WallRequestTab.top, 'r1').hidden, isTrue);
      expect(cubit.state.error, isNull);
    });
  });
}
