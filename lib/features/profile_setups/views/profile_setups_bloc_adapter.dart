import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/profile_setups/biz/bloc/profile_setups_bloc.j.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileSetupSnapshot {
  const ProfileSetupSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

class ProfileSetupsAdapter {
  ProfileSetupsAdapter(BuildContext context, {required bool listen})
    : _bloc = listen ? context.watch<ProfileSetupsBloc>() : context.read<ProfileSetupsBloc>();

  final ProfileSetupsBloc _bloc;

  List<ProfileSetupSnapshot>? get profileSetups {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items.map((item) => ProfileSetupSnapshot(item.payload)).toList(growable: false);
  }

  Future<void> getProfileSetups() async {
    final email = app_state.prismUser.email;
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

extension ProfileSetupsBlocAdapterX on BuildContext {
  ProfileSetupsAdapter profileSetupsAdapter({bool listen = true}) {
    return ProfileSetupsAdapter(this, listen: listen);
  }
}
