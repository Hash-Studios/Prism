import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/setups/biz/bloc/setups_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SetupsBuilder {
  const SetupsBuilder._();

  static Widget withBloc({required Widget child, SetupsBloc? bloc}) {
    return BlocProvider<SetupsBloc>(
      create: (_) => bloc ?? getIt<SetupsBloc>(),
      child: child,
    );
  }
}
