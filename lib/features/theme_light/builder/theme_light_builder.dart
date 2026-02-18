import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/theme_light/biz/bloc/theme_light_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeLightBuilder {
  const ThemeLightBuilder._();

  static Widget withBloc({required Widget child, ThemeLightBloc? bloc}) {
    return BlocProvider<ThemeLightBloc>(create: (_) => bloc ?? getIt<ThemeLightBloc>(), child: child);
  }
}
