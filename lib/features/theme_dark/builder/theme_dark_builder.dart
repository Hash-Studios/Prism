import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/theme_dark/biz/bloc/theme_dark_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeDarkBuilder {
  const ThemeDarkBuilder._();

  static Widget withBloc({required Widget child, ThemeDarkBloc? bloc}) {
    return BlocProvider<ThemeDarkBloc>(create: (_) => bloc ?? getIt<ThemeDarkBloc>(), child: child);
  }
}
