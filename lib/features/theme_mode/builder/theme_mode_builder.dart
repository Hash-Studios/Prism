import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_mode_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeModeBuilder {
  const ThemeModeBuilder._();

  static Widget withBloc({required Widget child, ThemeModeBloc? bloc}) {
    return BlocProvider<ThemeModeBloc>(
      create: (_) => bloc ?? getIt<ThemeModeBloc>(),
      child: child,
    );
  }
}
