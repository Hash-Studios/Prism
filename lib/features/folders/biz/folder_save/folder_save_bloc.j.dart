import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';
import 'package:Prism/features/folders/domain/repositories/folder_save_gateway.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'folder_save_event.j.dart';
part 'folder_save_state.j.dart';
part 'folder_save_bloc.j.freezed.dart';

/// Saves every wall of a folder. One run at a time for the whole app, so it keeps going after the folder page closes.
@lazySingleton
class FolderSaveBloc extends Bloc<FolderSaveEvent, FolderSaveState> {
  FolderSaveBloc(this._gateway) : super(const FolderSaveState.idle()) {
    on<_PlanRequested>(_onPlanRequested);
    on<_Started>(_onStarted);
    on<_CancelRequested>(_onCancelRequested);
    on<_RetryRequested>(_onRetryRequested);
    on<_Dismissed>(_onDismissed);
  }

  static const int maxParallel = 3;

  final FolderSaveGateway _gateway;
  bool _cancelled = false;
  int _planVersion = 0;
  int _watchers = 0;

  /// A folder page that shows the run calls this while it is on screen. With no watcher, the end of a run is announced.
  void watch() => _watchers++;
  void unwatch() => _watchers = math.max(0, _watchers - 1);

  Future<void> _onPlanRequested(_PlanRequested event, Emitter<FolderSaveState> emit) async {
    if (state is FolderSaveRunning) return;
    final int version = ++_planVersion;
    bool current() => version == _planVersion && state is FolderSavePlanning;
    final FolderSaveTarget target = event.target;
    emit(FolderSaveState.planning(target: target));
    try {
      final List<String> prismIds = <String>{
        for (final FolderSaveWall wall in event.walls)
          if (wall.source == WallpaperSource.prism) wall.id,
      }.toList(growable: false);
      final Map<String, WallAccess> access = await _gateway.wallAccess(prismIds);
      final Set<String> saved = <String>{};
      for (final FolderSaveWall wall in event.walls) {
        if (await _gateway.isSaved(wall)) saved.add(wall.key);
      }
      if (!current()) return;
      final FolderSavePlan plan = FolderSavePlan.build(
        walls: event.walls,
        access: access,
        account: _gateway.account(),
        isSaved: (wall) => saved.contains(wall.key),
      );
      emit(FolderSaveState.planned(target: target, plan: plan));
    } catch (error, stackTrace) {
      logger.w('Could not plan a folder save', error: error, stackTrace: stackTrace);
      if (current()) emit(FolderSaveState.planFailed(target: target));
    }
  }

  Future<void> _onStarted(_Started event, Emitter<FolderSaveState> emit) async {
    final FolderSaveState planned = state;
    if (planned is! FolderSavePlanned) return;
    final FolderSavePlan plan = planned.plan;
    final List<FolderSaveItem> queue = plan.walls(event.choice);
    final FolderSaveRun run = FolderSaveRun(queue: queue, skippedAtPlan: plan.count(FolderSaveKind.saved));
    _track(
      FolderSaveStartedEvent(
        wallCount: queue.length,
        coinCost: queue.fold(0, (sum, item) => sum + item.cost),
        pro: plan.isPro,
      ),
    );
    await _run(planned.target, run, queue, emit, event.announce);
  }

  Future<void> _onRetryRequested(_RetryRequested event, Emitter<FolderSaveState> emit) async {
    final FolderSaveState finished = state;
    if (finished is! FolderSaveFinished || finished.run.failed == 0) return;
    final List<FolderSaveItem> failed = finished.run.failedItems;
    _track(
      FolderSaveStartedEvent(
        wallCount: failed.length,
        coinCost: failed.fold(0, (sum, item) => sum + item.cost),
        pro: _gateway.account().isPro,
      ),
    );
    await _run(finished.target, finished.run.withFailedCleared(), failed, emit, event.announce);
  }

  void _onCancelRequested(_CancelRequested event, Emitter<FolderSaveState> emit) {
    final FolderSaveState running = state;
    if (running is! FolderSaveRunning || _cancelled) return;
    _cancelled = true;
    emit(running.copyWith(cancelling: true));
  }

  void _onDismissed(_Dismissed event, Emitter<FolderSaveState> emit) {
    if (state is FolderSaveRunning) return;
    _planVersion++;
    emit(const FolderSaveState.idle());
  }

  /// Saves [items] with at most [maxParallel] at a time. A cancel stops walls that have not started. A wall that has
  /// started runs to its end, so its coins are either kept for a saved file or given back.
  Future<void> _run(
    FolderSaveTarget target,
    FolderSaveRun run,
    List<FolderSaveItem> items,
    Emitter<FolderSaveState> emit,
    FolderSaveAnnouncer? announce,
  ) async {
    _cancelled = false;
    FolderSaveRun current = run;
    emit(FolderSaveState.running(target: target, run: current));
    await _gateway.clearTemporaryFiles();
    final FolderSaveAccess access = await _gateway.requestAccess(target.name);
    if (access != FolderSaveAccess.granted) {
      emit(FolderSaveState.accessDenied(target: target));
      return;
    }
    int next = 0;
    Future<void> worker() async {
      while (!_cancelled && next < items.length) {
        if (_gateway.ownerId != target.ownerId) {
          _cancelled = true;
          break;
        }
        final FolderSaveItem item = items[next++];
        FolderWallOutcome outcome;
        try {
          outcome = await _gateway.isSaved(item.wall)
              ? const FolderWallOutcome.skipped()
              : await _gateway.save(item, album: target.name, maxCoins: item.cost);
        } catch (error, stackTrace) {
          logger.w('A folder wall did not save', error: error, stackTrace: stackTrace);
          outcome = const FolderWallOutcome.failed(FolderSaveFailure.unknown);
        }
        current = current.withOutcome(item.wall, outcome);
        emit(FolderSaveState.running(target: target, run: current, cancelling: _cancelled));
      }
    }

    await Future.wait(<Future<void>>[for (int i = 0; i < math.min(maxParallel, items.length); i++) worker()]);
    await _gateway.clearTemporaryFiles();
    final bool cancelled = _cancelled && current.notStarted > 0;
    _cancelled = false;
    emit(FolderSaveState.finished(target: target, run: current, cancelled: cancelled));
    _track(
      cancelled
          ? FolderSaveCancelledEvent(saved: current.saved, notSaved: current.notStarted)
          : FolderSaveFinishedEvent(saved: current.saved, skipped: current.skipped, failed: current.failed),
    );
    if (_watchers == 0) announce?.call(target, current);
  }

  void _track(AnalyticsEvent event) {
    try {
      unawaited(analytics.track(event));
    } catch (error, stackTrace) {
      logger.w('Folder save analytics failed', error: error, stackTrace: stackTrace);
    }
  }
}
