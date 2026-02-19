import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/profile_walls/biz/bloc/profile_walls_bloc.j.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileWallSnapshot {
  const ProfileWallSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

extension ProfileWallsBlocAdapterX on BuildContext {
  ProfileWallsBloc _profileWallsBloc(bool listen) => listen ? watch<ProfileWallsBloc>() : read<ProfileWallsBloc>();

  List<ProfileWallSnapshot>? profileWallsSnapshots({bool listen = true}) {
    final state = _profileWallsBloc(listen).state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items.map((item) => ProfileWallSnapshot(item.payload)).toList(growable: false);
  }

  Future<void> loadProfileWalls() async {
    final email = app_state.prismUser.email;
    _profileWallsBloc(false).add(ProfileWallsEvent.started(email: email));
  }

  Future<void> fetchMoreProfileWalls() async {
    _profileWallsBloc(false).add(const ProfileWallsEvent.fetchMoreRequested());
  }
}
