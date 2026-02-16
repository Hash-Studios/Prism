import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/profile_walls/presentation/bloc/profile_walls_bloc.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LegacyProfileWallSnapshot {
  const LegacyProfileWallSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

extension ProfileWallsLegacyBridgeX on BuildContext {
  ProfileWallsBloc _profileWallsBloc(bool listen) => listen ? watch<ProfileWallsBloc>() : read<ProfileWallsBloc>();

  List<LegacyProfileWallSnapshot>? profileWallsLegacy({bool listen = true}) {
    final state = _profileWallsBloc(listen).state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items.map((item) => LegacyProfileWallSnapshot(item.payload)).toList(growable: false);
  }

  Future<void> loadProfileWalls() async {
    final email = globals.prismUser.email ?? '';
    _profileWallsBloc(false).add(ProfileWallsEvent.started(email: email));
  }

  Future<void> fetchMoreProfileWalls() async {
    _profileWallsBloc(false).add(const ProfileWallsEvent.fetchMoreRequested());
  }
}
