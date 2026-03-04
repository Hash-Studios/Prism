import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/profile_walls/biz/bloc/profile_walls_bloc.j.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_wall_entity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

extension ProfileWallsBlocAdapterX on BuildContext {
  ProfileWallsBloc _profileWallsBloc(bool listen) => listen ? watch<ProfileWallsBloc>() : read<ProfileWallsBloc>();

  List<ProfileWallEntity>? profileWalls({bool listen = true}) {
    final state = _profileWallsBloc(listen).state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items;
  }

  Future<void> loadProfileWalls() async {
    final email = app_state.prismUser.email;
    _profileWallsBloc(false).add(ProfileWallsEvent.started(email: email));
  }

  Future<void> fetchMoreProfileWalls() async {
    _profileWallsBloc(false).add(const ProfileWallsEvent.fetchMoreRequested());
  }
}
