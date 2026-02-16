import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/navigation/biz/bloc/navigation_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NavigationBuilder {
  const NavigationBuilder._();

  static Widget withBloc({required Widget child, NavigationBloc? bloc}) {
    return BlocProvider<NavigationBloc>(
      create: (_) => bloc ?? getIt<NavigationBloc>(),
      child: child,
    );
  }
}
