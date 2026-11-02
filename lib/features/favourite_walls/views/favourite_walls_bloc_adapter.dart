import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FavouritePinOutcome { done, limit, failed }

class FavouriteWallsAdapter {
  FavouriteWallsAdapter(BuildContext context, {required bool listen})
    : _bloc = listen ? context.watch<FavouriteWallsBloc>() : context.read<FavouriteWallsBloc>();

  static int _lastOperationId = 0;

  final FavouriteWallsBloc _bloc;

  Future<List<FavouriteWallEntity>?> getDataBase({bool forceRefresh = false}) async {
    await _ensureLoaded(forceRefresh: forceRefresh);
    final LoadStatus status = _bloc.state.status;
    return status == LoadStatus.initial || status == LoadStatus.failure ? null : _bloc.state.items;
  }

  /// Pass [desired] with the state the heart is going to show, so the tap never undoes a favourite that
  /// the list has not loaded yet.
  Future<bool> favCheck(FavouriteWallEntity wall, {bool? desired}) async {
    if (wall.id.isEmpty) {
      return false;
    }

    return _runAction((int id) => FavouriteWallsEvent.toggleRequested(wall: wall, desired: desired, operationId: id));
  }

  Future<bool> deleteData() => _runAction((int id) => FavouriteWallsEvent.clearRequested(operationId: id));

  Future<bool> removeWalls(List<String> wallIds) =>
      _runAction((int id) => FavouriteWallsEvent.removeRequested(wallIds: wallIds, operationId: id));

  Future<bool> restoreWalls(List<FavouriteWallEntity> walls) =>
      _runAction((int id) => FavouriteWallsEvent.restoreRequested(walls: walls, operationId: id));

  Future<FavouritePinOutcome> setPinned(String wallId, {required bool pinned}) async {
    await _ensureLoaded();
    final FavouriteWallsState completed = await _dispatch(
      (int id) => FavouriteWallsEvent.pinRequested(wallId: wallId, pinned: pinned, operationId: id),
    );
    if (completed.actionStatus == ActionStatus.success) return FavouritePinOutcome.done;
    return completed.failure is FavouritePinLimitFailure ? FavouritePinOutcome.limit : FavouritePinOutcome.failed;
  }

  Future<bool> _runAction(FavouriteWallsEvent Function(int operationId) eventFor) async {
    await _ensureLoaded();
    final before = _bloc.state.items
        .where((wall) => wall.source == WallpaperSource.prism)
        .map((wall) => wall.id)
        .toSet();
    final completed = await _dispatch(eventFor);
    final success = completed.actionStatus == ActionStatus.success;
    if (success) {
      final after = completed.items
          .where((wall) => wall.source == WallpaperSource.prism)
          .map((wall) => wall.id)
          .toSet();
      for (final id in before.difference(after).union(after.difference(before))) {
        getIt<FavouriteCountsCubit>().refreshAfterChange(id);
      }
    }
    return success;
  }

  Future<FavouriteWallsState> _dispatch(FavouriteWallsEvent Function(int operationId) eventFor) {
    final int operationId = ++_lastOperationId;
    final completion = _bloc.stream.firstWhere((state) => state.completedOperationId == operationId);
    _bloc.add(eventFor(operationId));
    return completion;
  }

  Future<void> _ensureLoaded({bool forceRefresh = false}) async {
    final userId = app_state.prismUser.id;

    if (_bloc.state.userId != userId || _bloc.state.status == LoadStatus.initial) {
      await _dispatch((int id) => FavouriteWallsEvent.started(userId: userId, operationId: id));
    } else if (forceRefresh || _bloc.state.status == LoadStatus.failure) {
      await _dispatch((int id) => FavouriteWallsEvent.refreshRequested(operationId: id));
    }
  }
}

extension FavouriteWallsBlocAdapterX on BuildContext {
  FavouriteWallsAdapter favouriteWallsAdapter({bool listen = true}) {
    return FavouriteWallsAdapter(this, listen: listen);
  }
}
