import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/profile_setups/presentation/bloc/profile_setups_bloc.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LegacyProfileSetupSnapshot {
  const LegacyProfileSetupSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

class LegacyProfileSetupsProvider {
  LegacyProfileSetupsProvider(BuildContext context, {required bool listen})
      : _bloc = listen ? context.watch<ProfileSetupsBloc>() : context.read<ProfileSetupsBloc>();

  final ProfileSetupsBloc _bloc;

  List<LegacyProfileSetupSnapshot>? get profileSetups {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items.map((item) => LegacyProfileSetupSnapshot(item.payload)).toList(growable: false);
  }

  Future<void> getProfileSetups() async {
    final email = globals.prismUser.email;
    _bloc.add(ProfileSetupsEvent.started(email: email));
    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }

  Future<void> seeMoreProfileSetups() async {
    if (_bloc.state.isFetchingMore || !_bloc.state.hasMore) {
      return;
    }
    final completion = _bloc.stream.firstWhere((state) => !state.isFetchingMore);
    _bloc.add(const ProfileSetupsEvent.fetchMoreRequested());
    await completion;
  }
}

extension ProfileSetupsLegacyBridgeX on BuildContext {
  LegacyProfileSetupsProvider profileSetupsLegacyProvider({bool listen = true}) {
    return LegacyProfileSetupsProvider(this, listen: listen);
  }
}
