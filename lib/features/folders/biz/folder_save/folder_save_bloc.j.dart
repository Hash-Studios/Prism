import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
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
  final Map<String, int> _watchers = <String, int>{};

  /// A page for this folder shows its run. Other folders do not suppress the completion announcement.
  void watch(String folderId) => _watchers.update(folderId, (count) => count + 1, ifAbsent: () => 1);

  void unwatch(String folderId) {
    final int count = (_watchers[folderId] ?? 0) - 1;
    if (count > 0) {
      _watchers[folderId] = count;
    } else {
      _watchers.remove(folderId);
    }
  }

  Future<void> _onPlanRequested(_PlanRequested event, Emitter<FolderSaveState> emit) async {
    if (state is FolderSaveRunning) return;
    final int version = ++_planVersion;
    bool current() => version == _planVersion && state is FolderSavePlanning;
    final FolderSaveTarget target = event.target;
    emit(FolderSaveState.planning(target: target));
    try {
      final List<String> prismIds = <String>{
        for (final FolderSaveWall wall in event.walls)
          if (wall.source == WallpaperSource.prism && !BundledWallpapers.isStarterIdentity(wall.id, wall.source))
            wall.id,
      }.toList(growable: false);
      final Map<String, WallAccess> access = await _gateway.wallAccess(prismIds);
      if (!current()) return;
      final Set<String> saved = <String>{};
      for (final FolderSaveWall wall in event.walls) {
        if (await _gateway.isSaved(wall)) saved.add(wall.key);
        if (!current()) return;
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

  /// Saves [items] with at most [maxParallel] at a time. A cancel stops walls that have not started. A started wall
  /// finishes; a failed Prism save keeps its paid original grant for retry rather than refunding it.
  Future<void> _run(
    FolderSaveTarget target,
    FolderSaveRun run,
    List<FolderSaveItem> items,
    Emitter<FolderSaveState> emit,
    FolderSaveAnnouncer? announce,
  ) async {
    _cancelled = false;
    FolderSaveRun current = run;
    bool canContinue() {
      if (_gateway.ownerId != target.ownerId) _cancelled = true;
      return !_cancelled;
    }

    emit(FolderSaveState.running(target: target, run: current));
    if (canContinue()) {
      await _gateway.clearTemporaryFiles();
      if (canContinue()) {
        final FolderSaveAccess access = await _gateway.requestAccess(target.name);
        if (canContinue() && access != FolderSaveAccess.granted) {
          emit(FolderSaveState.accessDenied(target: target));
          return;
        }
      }
    }
    Future<void> savePhase(List<FolderSaveItem> phase) async {
      int next = 0;
      Future<void> worker() async {
        while (canContinue() && next < phase.length) {
          final FolderSaveItem item = phase[next++];
          FolderWallOutcome outcome;
          try {
            final bool saved = await _gateway.isSaved(item.wall);
            if (!canContinue()) break;
            outcome = saved
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

      await Future.wait(<Future<void>>[for (int i = 0; i < math.min(maxParallel, phase.length); i++) worker()]);
    }

    // Wallhaven and Pexels files download before their charge. Keep paid walls from consuming their planned grace.
    await savePhase(items.where((item) => item.cost == 0).toList(growable: false));
    await savePhase(items.where((item) => item.cost > 0).toList(growable: false));
    await _gateway.clearTemporaryFiles();
    final bool cancelled = current.notStarted > 0;
    _cancelled = false;
    emit(FolderSaveState.finished(target: target, run: current, cancelled: cancelled));
    _track(
      cancelled
          ? FolderSaveCancelledEvent(saved: current.saved, notSaved: current.notStarted)
          : FolderSaveFinishedEvent(saved: current.saved, skipped: current.skipped, failed: current.failed),
    );
    if ((_watchers[target.folderId] ?? 0) == 0) announce?.call(target, current);
  }

  void _track(AnalyticsEvent event) {
    try {
      unawaited(analytics.track(event));
    } catch (error, stackTrace) {
      logger.w('Folder save analytics failed', error: error, stackTrace: stackTrace);
    }
  }
}
