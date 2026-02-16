import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/connectivity/biz/bloc/connectivity_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectivityBuilder {
  const ConnectivityBuilder._();

  static Widget withBloc({required Widget child, ConnectivityBloc? bloc}) {
    return BlocProvider<ConnectivityBloc>(
      create: (_) => bloc ?? getIt<ConnectivityBloc>(),
      child: child,
    );
  }
}
