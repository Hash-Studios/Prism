import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/setups/presentation/bloc/setups_bloc.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LegacySetupSnapshot {
  const LegacySetupSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

class LegacySetupsProvider {
  LegacySetupsProvider(BuildContext context, {required bool listen})
      : _bloc = listen ? context.watch<SetupsBloc>() : context.read<SetupsBloc>();

  final SetupsBloc _bloc;

  List<LegacySetupSnapshot>? get setups {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items.map((item) => LegacySetupSnapshot(item.payload)).toList(growable: false);
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

extension SetupsLegacyBridgeX on BuildContext {
  LegacySetupsProvider setupsLegacyProvider({bool listen = true}) {
    return LegacySetupsProvider(this, listen: listen);
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
