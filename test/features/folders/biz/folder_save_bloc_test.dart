import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/folders/biz/folder_save/folder_save_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';
import 'package:Prism/features/folders/domain/repositories/folder_save_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

const FolderSaveTarget _target = FolderSaveTarget(folderId: 'f1', name: 'Night', ownerId: 'u1');

const FolderSaveAccount _defaultAccount = FolderSaveAccount(
  isPro: false,
  premiumUnlocked: false,
  balance: 100,
  graceLeft: 0,
  price: 10,
);

FolderSaveWall _prism(String id) => FolderSaveWall(id: id, source: WallpaperSource.prism);

class FakeFolderSaveGateway implements FolderSaveGateway {
  @override
  String ownerId = 'u1';

  FolderSaveAccount accountValue = _defaultAccount;
  FolderSaveAccess access = FolderSaveAccess.granted;
  final Set<String> savedKeys = <String>{};
  final Map<String, FolderWallOutcome> outcomes = <String, FolderWallOutcome>{};
  final Map<String, Completer<FolderWallOutcome>> gates = <String, Completer<FolderWallOutcome>>{};
  final Map<String, Completer<bool>> savedGates = <String, Completer<bool>>{};
  final List<String> savedReads = <String>[];
  final List<String> accessCalls = <String>[];
  Completer<void>? clearGate;
  Completer<FolderSaveAccess>? accessGate;
  bool failAccessWhenNotEmpty = false;
  final List<List<String>> wallAccessCalls = <List<String>>[];
  final List<String> saveCalls = <String>[];
  final List<int> maxCoinsCalls = <int>[];
  int clears = 0;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  FolderSaveAccount account() => accountValue;

  @override
  Future<Map<String, WallAccess>> wallAccess(List<String> ids) async {
    wallAccessCalls.add(List<String>.of(ids));
    if (failAccessWhenNotEmpty && ids.isNotEmpty) throw StateError('offline');
    return <String, WallAccess>{for (final String id in ids) id: WallAccess.open};
  }

  @override
  Future<bool> isSaved(FolderSaveWall wall) async {
    savedReads.add(wall.id);
    return savedGates[wall.id]?.future ?? savedKeys.contains(wall.key);
  }

  @override
  Future<FolderSaveAccess> requestAccess(String album) async {
    accessCalls.add(album);
    return accessGate?.future ?? access;
  }

  @override
  Future<FolderWallOutcome> save(FolderSaveItem item, {required String album, required int maxCoins}) async {
    saveCalls.add(item.wall.id);
    maxCoinsCalls.add(maxCoins);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      final Completer<FolderWallOutcome>? gate = gates[item.wall.id];
      if (gate != null) return await gate.future;
      return outcomes[item.wall.id] ?? const FolderWallOutcome.saved();
    } finally {
      inFlight--;
    }
  }

  @override
  Future<void> clearTemporaryFiles() async {
    clears++;
    await clearGate?.future;
  }
}

/// The next state that matches [test]. Subscribe before the event is added.
Future<FolderSaveState> _next(FolderSaveBloc bloc, bool Function(FolderSaveState state) test) =>
    bloc.stream.firstWhere(test).timeout(const Duration(seconds: 5));

Future<FolderSavePlanned> _plan(FolderSaveBloc bloc, List<FolderSaveWall> walls) async {
  final Future<FolderSaveState> planned = _next(bloc, (FolderSaveState state) => state is FolderSavePlanned);
  bloc.add(FolderSaveEvent.planRequested(target: _target, walls: walls));
  return (await planned) as FolderSavePlanned;
}

Future<FolderSaveFinished> _runToEnd(
  FolderSaveBloc bloc, {
  FolderSaveChoice choice = FolderSaveChoice.all,
  FolderSaveAnnouncer? announce,
}) async {
  final Future<FolderSaveState> finished = _next(bloc, (FolderSaveState state) => state is FolderSaveFinished);
  bloc.add(FolderSaveEvent.started(choice: choice, announce: announce));
  return (await finished) as FolderSaveFinished;
}

/// Lets queued microtasks and events run until [condition] holds. Fails after a bounded number of turns.
Future<void> _until(bool Function() condition) async {
  for (int i = 0; i < 1000 && !condition(); i++) {
    await pumpEventQueue();
  }
  expect(condition(), isTrue);
}

void main() {
  late FakeFolderSaveGateway fake;
  late FolderSaveBloc bloc;

  setUp(() {
    fake = FakeFolderSaveGateway();
    bloc = FolderSaveBloc(fake);
  });

  tearDown(() => bloc.close());

  test('planRequested with three open Prism walls shows three coin walls costing 30', () async {
    final FolderSavePlanned planned = await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]);

    expect(planned.plan.count(FolderSaveKind.coins), 3);
    expect(planned.plan.totalCost, 30);
  });

  test('a starter-only plan needs no remote wall lookup when offline', () async {
    fake.failAccessWhenNotEmpty = true;
    final Future<FolderSaveState> planned = _next(
      bloc,
      (state) => state is FolderSavePlanned || state is FolderSavePlanFailed,
    );
    bloc.add(FolderSaveEvent.planRequested(target: _target, walls: <FolderSaveWall>[_prism('starter-sunset')]));

    final FolderSaveState result = await planned;

    expect(result, isA<FolderSavePlanned>());
    expect((result as FolderSavePlanned).plan.items.single.kind, FolderSaveKind.free);
    expect(fake.wallAccessCalls, <List<String>>[<String>[]]);
  });

  test('a dismissed plan cannot publish a late result', () async {
    final Completer<bool> saved = Completer<bool>();
    fake.savedGates['p1'] = saved;
    bloc.add(FolderSaveEvent.planRequested(target: _target, walls: <FolderSaveWall>[_prism('p1')]));
    await _until(() => fake.savedReads.isNotEmpty);
    bloc.add(const FolderSaveEvent.dismissed());
    await _until(() => bloc.state is FolderSaveIdle);

    saved.complete(false);
    await pumpEventQueue();

    expect(bloc.state, isA<FolderSaveIdle>());
  });

  test('a dismissed plan stops checking the remaining Downloads', () async {
    final Completer<bool> saved = Completer<bool>();
    fake.savedGates['p1'] = saved;
    bloc.add(
      FolderSaveEvent.planRequested(target: _target, walls: <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]),
    );
    await _until(() => fake.savedReads.isNotEmpty);
    bloc.add(const FolderSaveEvent.dismissed());
    await _until(() => bloc.state is FolderSaveIdle);

    saved.complete(false);
    await pumpEventQueue();

    expect(fake.savedReads, <String>['p1']);
    expect(bloc.state, isA<FolderSaveIdle>());
  });

  test('a newer plan cannot be overwritten by an older result', () async {
    final Completer<bool> saved = Completer<bool>();
    fake.savedGates['old'] = saved;
    bloc.add(FolderSaveEvent.planRequested(target: _target, walls: <FolderSaveWall>[_prism('old')]));
    await _until(() => fake.savedReads.isNotEmpty);
    await _plan(bloc, <FolderSaveWall>[_prism('new')]);

    saved.complete(false);
    await pumpEventQueue();

    expect((bloc.state as FolderSavePlanned).plan.items.single.wall.id, 'new');
  });

  test('overlapping start, plan, retry and dismiss events cannot replace a running save', () async {
    final Completer<FolderWallOutcome> saved = Completer<FolderWallOutcome>();
    fake.gates['p1'] = saved;
    await _plan(bloc, <FolderSaveWall>[_prism('p1')]);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.saveCalls.isNotEmpty);

    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    bloc.add(FolderSaveEvent.planRequested(target: _target, walls: <FolderSaveWall>[_prism('p2')]));
    bloc.add(const FolderSaveEvent.retryRequested());
    bloc.add(const FolderSaveEvent.dismissed());
    await pumpEventQueue();

    expect(bloc.state, isA<FolderSaveRunning>());
    expect(fake.saveCalls, <String>['p1']);
    expect(fake.clears, 1);
    final Future<FolderSaveState> finished = _next(bloc, (state) => state is FolderSaveFinished);
    saved.complete(const FolderWallOutcome.saved());
    final FolderSaveFinished done = (await finished) as FolderSaveFinished;
    expect(done.run.saved, 1);
    expect(fake.maxInFlight, 1);
  });

  test('a run emits progress 1 to 5 and finishes with 5 saved, free and never charged', () async {
    fake.accountValue = const FolderSaveAccount(
      isPro: false,
      premiumUnlocked: false,
      balance: 100,
      graceLeft: 5,
      price: 10,
    );
    final List<FolderSaveState> seen = <FolderSaveState>[];
    final StreamSubscription<FolderSaveState> sub = bloc.stream.listen(seen.add);
    addTearDown(sub.cancel);
    await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3'), _prism('p4'), _prism('p5')]);

    final FolderSaveFinished finished = await _runToEnd(bloc);

    final List<int> runningDone = <int>[
      for (final FolderSaveState state in seen)
        if (state is FolderSaveRunning) state.run.done,
    ];
    expect(runningDone, <int>[0, 1, 2, 3, 4, 5]);
    expect(finished.run.saved, 5);
    expect(finished.run.skipped, 0);
    expect(finished.run.failed, 0);
    expect(finished.cancelled, isFalse);
    expect(fake.maxInFlight, lessThanOrEqualTo(3));
    expect(fake.saveCalls, unorderedEquals(<String>['p1', 'p2', 'p3', 'p4', 'p5']));
    expect(fake.maxCoinsCalls, <int>[0, 0, 0, 0, 0]);
    expect(fake.clears, greaterThanOrEqualTo(1));
  });

  test('a run keeps at most three saves in flight and starts the fourth only after one finishes', () async {
    final List<String> ids = <String>['p1', 'p2', 'p3', 'p4', 'p5', 'p6'];
    for (final String id in ids) {
      fake.gates[id] = Completer<FolderWallOutcome>();
    }
    await _plan(bloc, ids.map(_prism).toList());

    final Future<FolderSaveState> finished = _next(bloc, (FolderSaveState state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.saveCalls.length == 3);
    await pumpEventQueue();
    expect(fake.saveCalls, hasLength(3));

    fake.gates['p1']!.complete(const FolderWallOutcome.saved());
    await _until(() => fake.saveCalls.length == 4);
    expect(fake.saveCalls, containsAll(<String>['p1', 'p2', 'p3', 'p4']));
    expect(fake.inFlight, 3);

    for (final String id in ids.skip(1)) {
      if (!fake.gates[id]!.isCompleted) fake.gates[id]!.complete(const FolderWallOutcome.saved());
    }
    final FolderSaveFinished done = (await finished) as FolderSaveFinished;

    expect(done.run.saved, 6);
    expect(fake.maxInFlight, 3);
  });

  test('paid walls wait until every planned-free wall has finished', () async {
    fake.accountValue = const FolderSaveAccount(
      isPro: false,
      premiumUnlocked: false,
      balance: 100,
      graceLeft: 2,
      price: 10,
    );
    final Completer<FolderWallOutcome> first = Completer<FolderWallOutcome>();
    final Completer<FolderWallOutcome> second = Completer<FolderWallOutcome>();
    fake.gates['free1'] = first;
    fake.gates['free2'] = second;
    await _plan(bloc, <FolderSaveWall>[_prism('free1'), _prism('free2'), _prism('paid')]);

    final Future<FolderSaveState> finished = _next(bloc, (state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.saveCalls.length >= 2);
    final List<String> beforeFreeFinished = List<String>.of(fake.saveCalls);
    first.complete(const FolderWallOutcome.saved());
    await pumpEventQueue();
    final List<String> beforeLastFreeFinished = List<String>.of(fake.saveCalls);
    second.complete(const FolderWallOutcome.saved());
    final FolderSaveFinished done = (await finished) as FolderSaveFinished;

    expect(beforeFreeFinished, <String>['free1', 'free2']);
    expect(beforeLastFreeFinished, <String>['free1', 'free2']);
    expect(fake.saveCalls, <String>['free1', 'free2', 'paid']);
    expect(done.run.saved, 3);
  });

  test('cancel stops walls that have not started and leaves them uncharged', () async {
    final List<String> ids = <String>['p1', 'p2', 'p3', 'p4', 'p5', 'p6'];
    for (final String id in ids) {
      fake.gates[id] = Completer<FolderWallOutcome>();
    }
    await _plan(bloc, ids.map(_prism).toList());

    final Future<FolderSaveState> finished = _next(bloc, (FolderSaveState state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.inFlight == 3);

    final Future<FolderSaveState> cancelling = _next(
      bloc,
      (FolderSaveState state) => state is FolderSaveRunning && state.cancelling,
    );
    bloc.add(const FolderSaveEvent.cancelRequested());
    final FolderSaveState cancellingState = await cancelling;
    expect((cancellingState as FolderSaveRunning).cancelling, isTrue);

    for (final String id in <String>['p1', 'p2', 'p3']) {
      fake.gates[id]!.complete(const FolderWallOutcome.saved());
    }
    final FolderSaveFinished done = (await finished) as FolderSaveFinished;

    expect(done.cancelled, isTrue);
    expect(done.run.saved, 3);
    expect(done.run.notStarted, 3);
    expect(fake.saveCalls, hasLength(3));
    expect(fake.maxCoinsCalls, <int>[10, 10, 10]);
  });

  test('retry saves only the failed wall and finishes with 3 saved and 0 failed', () async {
    fake.outcomes['p2'] = const FolderWallOutcome.failed(FolderSaveFailure.network);
    await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]);

    final FolderSaveFinished first = await _runToEnd(bloc);
    expect(first.run.saved, 2);
    expect(first.run.failed, 1);

    fake.outcomes.remove('p2');
    final Future<FolderSaveState> retried = _next(
      bloc,
      (FolderSaveState state) => state is FolderSaveFinished && state.run.saved == 3,
    );
    bloc.add(const FolderSaveEvent.retryRequested());
    final FolderSaveFinished second = (await retried) as FolderSaveFinished;

    expect(second.run.saved, 3);
    expect(second.run.failed, 0);
    expect(fake.saveCalls, unorderedEquals(<String>['p1', 'p2', 'p2', 'p3']));
  });

  test('retry preserves the not-started summary of a cancelled run', () async {
    final List<String> ids = <String>['p1', 'p2', 'p3', 'p4', 'p5', 'p6'];
    for (final String id in ids.take(3)) {
      fake.gates[id] = Completer<FolderWallOutcome>();
    }
    await _plan(bloc, ids.map(_prism).toList());
    final Future<FolderSaveState> firstFinished = _next(bloc, (state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.inFlight == 3);
    bloc.add(const FolderSaveEvent.cancelRequested());
    await _until(() => bloc.state is FolderSaveRunning && (bloc.state as FolderSaveRunning).cancelling);
    fake.gates['p1']!.complete(const FolderWallOutcome.failed(FolderSaveFailure.network));
    fake.gates['p2']!.complete(const FolderWallOutcome.saved());
    fake.gates['p3']!.complete(const FolderWallOutcome.saved());
    await firstFinished;
    fake.gates.clear();

    final Future<FolderSaveState> retried = _next(bloc, (state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.retryRequested());
    final FolderSaveFinished done = (await retried) as FolderSaveFinished;

    expect(done.run.saved, 3);
    expect(done.run.failed, 0);
    expect(done.run.notStarted, 3);
    expect(done.cancelled, isTrue);
    expect(fake.saveCalls, <String>['p1', 'p2', 'p3', 'p1']);
  });

  test('a wall already in Downloads is counted as saved at plan time and never saved again', () async {
    fake.savedKeys.add('prism:p1');
    final FolderSavePlanned planned = await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]);
    expect(planned.plan.count(FolderSaveKind.saved), 1);

    final FolderSaveFinished finished = await _runToEnd(bloc);

    expect(finished.run.skipped, 1);
    expect(finished.run.saved, 2);
    expect(fake.saveCalls, isNot(contains('p1')));
    expect(fake.saveCalls, unorderedEquals(<String>['p2', 'p3']));
  });

  test('a wall that lands in Downloads after planning is skipped at run time', () async {
    await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]);
    fake.savedKeys.add('prism:p3');

    final FolderSaveFinished finished = await _runToEnd(bloc);

    expect(finished.run.skipped, 1);
    expect(finished.run.saved, 2);
    expect(fake.saveCalls, isNot(contains('p3')));
  });

  test('a refused photos access shows access denied and saves nothing', () async {
    await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2')]);
    fake.access = FolderSaveAccess.denied;

    final Future<FolderSaveState> denied = _next(bloc, (FolderSaveState state) => state is FolderSaveAccessDenied);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));

    expect(await denied, isA<FolderSaveAccessDenied>());
    expect(fake.saveCalls, isEmpty);
  });

  test('a signed-in account change stops the run before any save', () async {
    await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]);
    fake.ownerId = 'other';

    final FolderSaveFinished finished = await _runToEnd(bloc);

    expect(fake.saveCalls, isEmpty);
    expect(fake.accessCalls, isEmpty);
    expect(finished.cancelled, isTrue);
    expect(finished.run.notStarted, 3);
  });

  test('cancel during the Downloads check does not start a save', () async {
    await _plan(bloc, <FolderSaveWall>[_prism('p1')]);
    final Completer<bool> saved = Completer<bool>();
    fake.savedGates['p1'] = saved;
    final Future<FolderSaveState> finished = _next(bloc, (state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.savedReads.length == 2);
    bloc.add(const FolderSaveEvent.cancelRequested());
    await _until(() => bloc.state is FolderSaveRunning && (bloc.state as FolderSaveRunning).cancelling);
    saved.complete(false);

    final FolderSaveFinished done = (await finished) as FolderSaveFinished;
    expect(fake.saveCalls, isEmpty);
    expect(done.cancelled, isTrue);
    expect(done.run.notStarted, 1);
  });

  test('an account change during the Downloads check does not save for the new account', () async {
    await _plan(bloc, <FolderSaveWall>[_prism('p1')]);
    final Completer<bool> saved = Completer<bool>();
    fake.savedGates['p1'] = saved;
    final Future<FolderSaveState> finished = _next(bloc, (state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.savedReads.length == 2);
    fake.ownerId = 'other';
    saved.complete(false);

    final FolderSaveFinished done = (await finished) as FolderSaveFinished;
    expect(fake.saveCalls, isEmpty);
    expect(done.cancelled, isTrue);
    expect(done.run.notStarted, 1);
  });

  test('an account change during startup cleanup does not request access', () async {
    await _plan(bloc, <FolderSaveWall>[_prism('p1')]);
    final Completer<void> clear = Completer<void>();
    fake.clearGate = clear;
    final Future<FolderSaveState> finished = _next(bloc, (state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.clears == 1);
    fake.ownerId = 'other';
    clear.complete();

    final FolderSaveFinished done = (await finished) as FolderSaveFinished;
    expect(fake.accessCalls, isEmpty);
    expect(fake.saveCalls, isEmpty);
    expect(done.cancelled, isTrue);
  });

  test('cancel while waiting for permission does not start any wall', () async {
    await _plan(bloc, <FolderSaveWall>[_prism('p1')]);
    final Completer<FolderSaveAccess> access = Completer<FolderSaveAccess>();
    fake.accessGate = access;
    final Future<FolderSaveState> finished = _next(bloc, (state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await _until(() => fake.accessCalls.isNotEmpty);
    bloc.add(const FolderSaveEvent.cancelRequested());
    await _until(() => bloc.state is FolderSaveRunning && (bloc.state as FolderSaveRunning).cancelling);
    access.complete(FolderSaveAccess.granted);

    final FolderSaveFinished done = (await finished) as FolderSaveFinished;
    expect(fake.saveCalls, isEmpty);
    expect(done.cancelled, isTrue);
    expect(done.run.notStarted, 1);
  });

  test('retry after an account change does not request permission or save', () async {
    fake.outcomes['p1'] = const FolderWallOutcome.failed(FolderSaveFailure.network);
    await _plan(bloc, <FolderSaveWall>[_prism('p1')]);
    await _runToEnd(bloc);
    fake.accessCalls.clear();
    fake.saveCalls.clear();
    fake.ownerId = 'other';

    final Future<FolderSaveState> finished = _next(bloc, (state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.retryRequested());
    final FolderSaveFinished done = (await finished) as FolderSaveFinished;

    expect(fake.accessCalls, isEmpty);
    expect(fake.saveCalls, isEmpty);
    expect(done.cancelled, isTrue);
    expect(done.run.notStarted, 1);
  });

  test('the announcer is called once with the finished run when no folder page watches', () async {
    final List<FolderSaveRun> announced = <FolderSaveRun>[];
    await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]);

    final FolderSaveFinished finished = await _runToEnd(
      bloc,
      announce: (FolderSaveTarget target, FolderSaveRun run) => announced.add(run),
    );
    await pumpEventQueue();

    expect(announced, hasLength(1));
    expect(announced.single.saved, 3);
    expect(announced.single.total, finished.run.total);
  });

  test('the announcer is not called when a folder page watches the run', () async {
    final List<FolderSaveRun> announced = <FolderSaveRun>[];
    bloc.watch(_target.folderId);
    await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]);

    await _runToEnd(bloc, announce: (FolderSaveTarget target, FolderSaveRun run) => announced.add(run));
    await pumpEventQueue();

    expect(announced, isEmpty);
  });
}
