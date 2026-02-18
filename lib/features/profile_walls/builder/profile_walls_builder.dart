import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/profile_walls/biz/bloc/profile_walls_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileWallsBuilder {
  const ProfileWallsBuilder._();

  static Widget withBloc({required Widget child, ProfileWallsBloc? bloc}) {
    return BlocProvider<ProfileWallsBloc>(create: (_) => bloc ?? getIt<ProfileWallsBloc>(), child: child);
  }
}
