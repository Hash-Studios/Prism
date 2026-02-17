import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/setups/biz/bloc/setups_bloc.j.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SetupSnapshot {
  const SetupSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

class SetupsAdapter {
  SetupsAdapter(BuildContext context, {required bool listen})
      : _bloc = listen ? context.watch<SetupsBloc>() : context.read<SetupsBloc>();

  final SetupsBloc _bloc;

  List<SetupSnapshot>? get setups {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items.map((item) => SetupSnapshot(item.payload)).toList(growable: false);
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

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
Map? setup;

Future<Map?> getSetupFromName(String? name) async {
  setup = {};
  await databaseReference.collection('setups').where('name', isEqualTo: name).get().then((value) {
    for (final doc in value.docs) {
      setup = doc.data();
    }
    logger.d(setup.toString());
  }).catchError((error) {
    logger.d('data done with error');
    logger.d(error.toString());
  });
  return setup;
}
