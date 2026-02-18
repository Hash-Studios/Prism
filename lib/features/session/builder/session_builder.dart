import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SessionBuilder {
  const SessionBuilder._();

  static Widget withBloc({required Widget child, SessionBloc? bloc}) {
    return BlocProvider<SessionBloc>(create: (_) => bloc ?? getIt<SessionBloc>(), child: child);
  }
}
