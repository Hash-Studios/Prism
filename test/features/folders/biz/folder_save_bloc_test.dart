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
  final List<String> saveCalls = <String>[];
  final List<int> maxCoinsCalls = <int>[];
  int clears = 0;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  FolderSaveAccount account() => accountValue;

  @override
  Future<Map<String, WallAccess>> wallAccess(List<String> ids) async => <String, WallAccess>{
    for (final String id in ids) id: WallAccess.open,
  };

  @override
  Future<bool> isSaved(FolderSaveWall wall) async => savedKeys.contains(wall.key);

  @override
  Future<FolderSaveAccess> requestAccess(String album) async => access;

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
    expect(finished.cancelled, isTrue);
    expect(finished.run.notStarted, 3);
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
    bloc.watch();
    await _plan(bloc, <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')]);

    await _runToEnd(bloc, announce: (FolderSaveTarget target, FolderSaveRun run) => announced.add(run));
    await pumpEventQueue();

    expect(announced, isEmpty);
  });
}
