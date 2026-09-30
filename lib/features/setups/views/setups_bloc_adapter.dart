import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/setups/biz/bloc/setups_bloc.j.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SetupsAdapter {
  SetupsAdapter(BuildContext context, {required bool listen})
    : _bloc = listen ? context.watch<SetupsBloc>() : context.read<SetupsBloc>();

  final SetupsBloc _bloc;

  List<SetupEntity>? get setups {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items;
  }

  Future<void> getSetups() async {
    _bloc.add(const SetupsEvent.started());
    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }

  Future<void> seeMoreSetups() async {
    if (_bloc.state.isFetchingMore || !_bloc.state.hasMore) {
      return;
    }

    final completion = _bloc.stream.firstWhere((state) => !state.isFetchingMore);
    _bloc.add(const SetupsEvent.fetchMoreRequested());
    await completion;
  }
}

extension SetupsBlocAdapterX on BuildContext {
  SetupsAdapter setupsAdapter({bool listen = true}) {
    return SetupsAdapter(this, listen: listen);
  }
}
