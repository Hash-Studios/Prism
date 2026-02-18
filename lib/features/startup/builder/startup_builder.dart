import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StartupBuilder {
  const StartupBuilder._();

  static Widget withBloc({required Widget child, StartupBloc? bloc}) {
    return BlocProvider<StartupBloc>(create: (_) => bloc ?? getIt<StartupBloc>(), child: child);
  }
}
