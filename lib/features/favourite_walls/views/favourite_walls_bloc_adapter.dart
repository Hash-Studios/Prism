import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteWallsAdapter {
  FavouriteWallsAdapter(BuildContext context, {required bool listen})
    : _bloc = listen ? context.watch<FavouriteWallsBloc>() : context.read<FavouriteWallsBloc>();

  final FavouriteWallsBloc _bloc;

  List<FavouriteWallEntity>? get liked {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items;
  }

  Future<List<FavouriteWallEntity>?> getDataBase({bool forceRefresh = false}) async {
    await _ensureLoaded(forceRefresh: forceRefresh);
    return liked;
  }

  Future<void> favCheck(FavouriteWallEntity wall) async {
    if (wall.id.isEmpty) {
      return;
    }

    final userId = app_state.prismUser.id;
    if (userId.isEmpty) {
      return;
    }

    await _ensureLoaded();

    final completion = _bloc.stream.firstWhere((state) => state.actionStatus != ActionStatus.inProgress);
    _bloc.add(FavouriteWallsEvent.toggleRequested(wall: wall));
    await completion;
  }

  Future<bool> deleteData() async {
    final userId = app_state.prismUser.id;
    if (userId.isEmpty) {
      return false;
    }

    await _ensureLoaded();
    final completion = _bloc.stream.firstWhere((state) => state.actionStatus != ActionStatus.inProgress);
    _bloc.add(const FavouriteWallsEvent.clearRequested());
    await completion;
    return _bloc.state.actionStatus == ActionStatus.success;
  }

  Future<void> _ensureLoaded({bool forceRefresh = false}) async {
    final userId = app_state.prismUser.id;
    if (userId.isEmpty) {
      return;
    }

    if (_bloc.state.userId != userId || _bloc.state.status == LoadStatus.initial) {
      _bloc.add(FavouriteWallsEvent.started(userId: userId));
    } else if (forceRefresh || _bloc.state.status == LoadStatus.failure) {
      _bloc.add(const FavouriteWallsEvent.refreshRequested());
    } else {
      return;
    }

    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }
}

extension FavouriteWallsBlocAdapterX on BuildContext {
  FavouriteWallsAdapter favouriteWallsAdapter({bool listen = true}) {
    return FavouriteWallsAdapter(this, listen: listen);
  }
}
