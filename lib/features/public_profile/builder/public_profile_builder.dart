import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PublicProfileBuilder {
  const PublicProfileBuilder._();

  static Widget withBloc({required Widget child, PublicProfileBloc? bloc}) {
    return BlocProvider<PublicProfileBloc>(
      create: (_) => bloc ?? getIt<PublicProfileBloc>(),
      child: child,
    );
  }
}
