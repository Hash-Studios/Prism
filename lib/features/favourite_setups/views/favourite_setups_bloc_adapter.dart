import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_setups/biz/bloc/favourite_setups_bloc.j.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteSetupsAdapter {
  FavouriteSetupsAdapter(BuildContext context, {required bool listen})
    : _bloc = listen ? context.watch<FavouriteSetupsBloc>() : context.read<FavouriteSetupsBloc>();

  final FavouriteSetupsBloc _bloc;

  List<SetupEntity>? get items {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items;
  }

  Future<void> load() => _ensureLoaded();

  Future<void> toggle(SetupEntity setup) async {
    if (setup.id.isEmpty) {
      return;
    }

    final userId = app_state.prismUser.id;
    if (userId.isEmpty) {
      return;
    }

    await _ensureLoaded();

    final completion = _bloc.stream.firstWhere((state) => state.actionStatus != ActionStatus.inProgress);
    _bloc.add(FavouriteSetupsEvent.toggleRequested(setup: setup));
    await completion;
  }

  Future<void> _ensureLoaded() async {
    final userId = app_state.prismUser.id;
    if (userId.isEmpty) {
      return;
    }

    if (_bloc.state.userId != userId || _bloc.state.status == LoadStatus.initial) {
      _bloc.add(FavouriteSetupsEvent.started(userId: userId));
    } else {
      _bloc.add(const FavouriteSetupsEvent.refreshRequested());
    }

    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }
}

extension FavouriteSetupsBlocAdapterX on BuildContext {
  FavouriteSetupsAdapter favouriteSetupsAdapter({bool listen = true}) {
    return FavouriteSetupsAdapter(this, listen: listen);
  }
}
