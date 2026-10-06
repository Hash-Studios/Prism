import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteWallsAdapter {
  FavouriteWallsAdapter(BuildContext context, {required bool listen})
    : _bloc = listen ? context.watch<FavouriteWallsBloc>() : context.read<FavouriteWallsBloc>();

  static int _lastOperationId = 0;

  final FavouriteWallsBloc _bloc;

  Future<List<FavouriteWallEntity>?> getDataBase({bool forceRefresh = false}) async {
    await _ensureLoaded(forceRefresh: forceRefresh);
    return _bloc.state.status == LoadStatus.initial ? null : _bloc.state.items;
  }

  Future<bool> favCheck(FavouriteWallEntity wall) async {
    if (wall.id.isEmpty) {
      return false;
    }

    final userId = app_state.prismUser.id;
    if (userId.isEmpty) {
      return false;
    }

    return _runAction((int id) => FavouriteWallsEvent.toggleRequested(wall: wall, operationId: id));
  }

  Future<bool> deleteData() => _runAction((int id) => FavouriteWallsEvent.clearRequested(operationId: id));

  Future<bool> removeWalls(List<String> wallIds) =>
      _runAction((int id) => FavouriteWallsEvent.removeRequested(wallIds: wallIds, operationId: id));

  Future<bool> restoreWalls(List<FavouriteWallEntity> walls) =>
      _runAction((int id) => FavouriteWallsEvent.restoreRequested(walls: walls, operationId: id));

  Future<bool> _runAction(FavouriteWallsEvent Function(int operationId) eventFor) async {
    if (app_state.prismUser.id.isEmpty) {
      return false;
    }

    await _ensureLoaded();
    return (await _dispatch(eventFor)).actionStatus == ActionStatus.success;
  }

  Future<FavouriteWallsState> _dispatch(FavouriteWallsEvent Function(int operationId) eventFor) {
    final int operationId = ++_lastOperationId;
    final completion = _bloc.stream.firstWhere((state) => state.completedOperationId == operationId);
    _bloc.add(eventFor(operationId));
    return completion;
  }

  Future<void> _ensureLoaded({bool forceRefresh = false}) async {
    final userId = app_state.prismUser.id;
    if (userId.isEmpty) {
      return;
    }

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
