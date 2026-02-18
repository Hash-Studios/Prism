import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/profile_setups/biz/bloc/profile_setups_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileSetupsBuilder {
  const ProfileSetupsBuilder._();

  static Widget withBloc({required Widget child, ProfileSetupsBloc? bloc}) {
    return BlocProvider<ProfileSetupsBloc>(create: (_) => bloc ?? getIt<ProfileSetupsBloc>(), child: child);
  }
}
