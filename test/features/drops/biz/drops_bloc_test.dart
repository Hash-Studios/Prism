import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/fake_app_analytics.dart';
import '../drop_fixtures.dart';

class _MockRepository extends Mock implements DropsRepository {}

Map<String, Object?> _reply({
  required bool success,
  String reason = 'ok',
  List<String> unlocked = const <String>[],
  int delta = -30,
  bool insufficient = false,
}) => <String, Object?>{
  'success': success,
  'changed': success,
  'previousBalance': 100,
  'currentBalance': 100 + delta,
  'delta': success ? delta : 0,
  'reason': reason,
  if (insufficient) 'insufficientBalance': true,
  'unlocked': [
    for (final String id in unlocked) <String, String>{'id': id, 'url': 'https://full.test/$id.jpg'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  late _MockRepository repository;
  late FakeAppAnalytics analytics;
  late DropsBloc bloc;
  late List<(String, Map<String, dynamic>)> calls;

  setUpAll(() => registerFallbackValue(DateTime.utc(2026)));

  setUp(() async {
    await backend.install();
    calls = <(String, Map<String, dynamic>)>[];
    CoinsService.instance.balanceNotifier.value = 100;
    CoinsService.instance.dropsUnlockedNotifier.value = const <String, DropUnlock>{};
    repository = _MockRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    bloc = DropsBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  void stubLoad({DropEntity? live, List<DropEntity> past = const <DropEntity>[]}) {
    when(() => repository.fetchLive(any())).thenAnswer((_) async => Result.success(live));
    when(() => repository.fetchByWeekKey(any())).thenAnswer((_) async => Result.success(null));
    for (final DropEntity drop in past) {
      when(() => repository.fetchByWeekKey(drop.weekKey)).thenAnswer((_) async => Result.success(drop));
    }
  }

  void reply(Object? Function(String name, Map<String, dynamic> params) answer) {
    backend.onCall = (name, params) async {
      calls.add((name, params));
      return answer(name, params);
    };
  }

  Future<DropsState> loaded() {
    bloc.add(const DropsEvent.started());
    return bloc.stream.firstWhere((s) => s.status == LoadStatus.success || s.status == LoadStatus.failure);
  }

  test('started loads this week and the vault, and records the view', () async {
    final live = dropEntity();
    final old = dropEntity(weekKey: '2026-W41', startedAgo: const Duration(days: 9), endsIn: const Duration(days: -2));
    stubLoad(live: live, past: <DropEntity>[old]);
    CoinsService.instance.dropsUnlockedNotifier.value = const <String, DropUnlock>{
      'A': DropUnlock(wallId: 'A', weekKey: '2026-W41', url: 'https://full.test/A.jpg'),
    };

    await loaded();
    await pumpEventQueue();
    final DropsState state = bloc.state;

    expect(state.drop, live);
    expect(state.past, <DropEntity>[old]);
    expect(state.isLive, isTrue);
    expect(state.vault, <DropEntity>[old]);
    expect(state.lockedWalls.length, 3);
    expect(analytics.events.single.eventName, 'drop_viewed');
    expect(analytics.events.single.toWireParameters(), containsPair('week_key', '2026-W42'));
  });

  test('a past Drop with no owned wall is never fetched', () async {
    stubLoad(
      live: dropEntity(),
      past: <DropEntity>[
        dropEntity(weekKey: '2026-W41', wallIds: <String>['X']),
      ],
    );

    expect((await loaded()).vault, isEmpty);
    verifyNever(() => repository.fetchByWeekKey(any()));
  });

  test('the vault holds every owned week, not only recent ones, and fetches each Drop once', () async {
    final List<DropEntity> old = <DropEntity>[
      for (int week = 1; week <= 20; week++)
        dropEntity(weekKey: '2025-W${week.toString().padLeft(2, '0')}', wallIds: <String>['W$week']),
    ];
    stubLoad(live: dropEntity(), past: old);
    CoinsService.instance.dropsUnlockedNotifier.value = <String, DropUnlock>{
      for (int week = 1; week <= 20; week++)
        'W$week': DropUnlock(wallId: 'W$week', weekKey: '2025-W${week.toString().padLeft(2, '0')}', url: 'u'),
    };

    await loaded();
    await pumpEventQueue();
    final DropsState state = bloc.state;
    expect(state.vault.map((DropEntity d) => d.weekKey).first, '2025-W20');
    expect(state.vault, hasLength(20));

    CoinsService.instance.dropsUnlockedNotifier.value = <String, DropUnlock>{
      ...CoinsService.instance.dropsUnlockedNotifier.value,
      'A': const DropUnlock(wallId: 'A', weekKey: '2026-W42', url: 'u'),
    };
    await pumpEventQueue();
    verify(() => repository.fetchByWeekKey('2025-W01')).called(1);
    verifyNever(() => repository.fetchByWeekKey('2026-W42'));
  });

  test('the vault fetches at most the newest 52 owned weeks', () async {
    stubLoad();
    CoinsService.instance.dropsUnlockedNotifier.value = <String, DropUnlock>{
      for (int i = 0; i < 60; i++)
        'W$i': DropUnlock(
          wallId: 'W$i',
          weekKey: '${2020 + i ~/ 50}-W${(i % 50 + 1).toString().padLeft(2, '0')}',
          url: 'u',
        ),
    };

    await loaded();
    await pumpEventQueue();
    verify(() => repository.fetchByWeekKey(any())).called(DropsBloc.vaultCap);
  });

  test('started with a week key loads that Drop only', () async {
    final old = dropEntity(weekKey: '2026-W41', endsIn: const Duration(days: -2));
    when(() => repository.fetchByWeekKey('2026-W41')).thenAnswer((_) async => Result.success(old));

    bloc.add(const DropsEvent.started(weekKey: '2026-W41'));
    final state = await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    expect(state.drop, old);
    expect(state.isLive, isFalse);
    verifyNever(() => repository.fetchLive(any()));
  });

  test('a failed load of the live Drop is a failure', () async {
    when(() => repository.fetchLive(any())).thenAnswer((_) async => Result.error(const ServerFailure('x')));

    expect((await loaded()).status, LoadStatus.failure);
  });

  test('a failed vault load still shows the live Drop', () async {
    when(() => repository.fetchLive(any())).thenAnswer((_) async => Result.success(dropEntity()));
    when(() => repository.fetchByWeekKey(any())).thenAnswer((_) async => Result.error(const ServerFailure('x')));
    CoinsService.instance.dropsUnlockedNotifier.value = const <String, DropUnlock>{
      'A': DropUnlock(wallId: 'A', weekKey: '2026-W41', url: 'https://full.test/A.jpg'),
    };

    final state = await loaded();

    expect(state.status, LoadStatus.success);
    expect(state.past, isEmpty);
  });

  group('unlockRequested', () {
    test('one wall: calls the callable, keeps the url and tracks the unlock at the wall price', () async {
      stubLoad(live: dropEntity());
      await loaded();
      reply((_, _) => _reply(success: true, unlocked: <String>['A']));

      bloc.add(const DropsEvent.unlockRequested(wallId: 'A'));
      final state = await bloc.stream.firstWhere((s) => s.lastResult != null);

      expect(calls.single.$1, 'unlockDrop');
      expect(calls.single.$2, containsPair('wallId', 'A'));
      expect(state.lastResult!.outcome, DropUnlockOutcome.unlocked);
      expect(state.busyKey, isNull);
      await pumpEventQueue();
      final settled = bloc.state;
      expect(settled.unlocked['A']!.url, 'https://full.test/A.jpg');
      expect(settled.lockedWalls.length, 3);
      final event = analytics.events.firstWhere((e) => e.eventName == 'drop_unlocked');
      expect(event.toWireParameters(), <String, Object?>{'week_key': '2026-W42', 'pack': 0, 'count': 1, 'price': 30});
    });

    test('the pack is capped by the pack price, halved for Pro', () async {
      app_state.prismUser.premium = true;
      stubLoad(live: dropEntity());
      await loaded();
      reply((_, _) => _reply(success: true, unlocked: <String>['A', 'B', 'C', 'D']));

      bloc.add(const DropsEvent.unlockRequested());
      await bloc.stream.firstWhere((s) => s.lastResult != null);

      expect(calls.single.$2['wallId'], isNull);
      final event = analytics.events.firstWhere((e) => e.eventName == 'drop_unlocked');
      expect(event.toWireParameters(), <String, Object?>{'week_key': '2026-W42', 'pack': 1, 'count': 4, 'price': 50});
    });

    test('too few coins gives an insufficient result and no unlock event', () async {
      stubLoad(live: dropEntity());
      await loaded();
      reply((_, _) => _reply(success: false, reason: 'dropWall_insufficient_balance', insufficient: true));

      bloc.add(const DropsEvent.unlockRequested(wallId: 'A'));
      final state = await bloc.stream.firstWhere((s) => s.lastResult != null);

      expect(state.lastResult!.outcome, DropUnlockOutcome.insufficient);
      expect(state.unlocked, isEmpty);
      expect(analytics.events.where((e) => e.eventName == 'drop_unlocked'), isEmpty);
    });

    test('is ignored with no Drop loaded', () async {
      bloc.add(const DropsEvent.unlockRequested(wallId: 'A'));
      await Future<void>.delayed(Duration.zero);

      expect(calls, isEmpty);
    });
  });

  group('renameRequested', () {
    test('renames the Drop, emits an ok result and reloads the Drop', () async {
      stubLoad(live: dropEntity());
      await loaded();
      clearInteractions(repository);
      when(() => repository.rename(any(), any())).thenAnswer((_) async => Result.success('Night Swim'));

      bloc.add(const DropsEvent.renameRequested(title: 'Night Swim'));
      final DropsState state = await bloc.stream.firstWhere((s) => s.lastRename != null);

      expect(state.lastRename!.ok, isTrue);
      await pumpEventQueue();
      verify(() => repository.rename('2026-W42', 'Night Swim')).called(1);
      verify(() => repository.fetchLive(any())).called(1);
    });

    test('a failed rename emits a not ok result and does not reload', () async {
      stubLoad(live: dropEntity());
      await loaded();
      clearInteractions(repository);
      when(() => repository.rename(any(), any())).thenAnswer((_) async => Result.error(const ServerFailure('x')));

      bloc.add(const DropsEvent.renameRequested(title: 'Night Swim'));
      final DropsState state = await bloc.stream.firstWhere((s) => s.lastRename != null);

      expect(state.lastRename!.ok, isFalse);
      await pumpEventQueue();
      verifyNever(() => repository.fetchLive(any()));
    });
  });

  test('a ticked event moves the clock', () async {
    stubLoad(live: dropEntity());
    final before = (await loaded()).now;
    await Future<void>.delayed(const Duration(milliseconds: 5));

    bloc.add(const DropsEvent.ticked());
    final after = await bloc.stream.firstWhere((s) => s.now.isAfter(before));

    expect(after.now.isAfter(before), isTrue);
  });
}
