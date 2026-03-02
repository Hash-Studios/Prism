import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WotdBuilder {
  const WotdBuilder._();

  static Widget withBloc({required Widget child, WotdBloc? bloc}) {
    return BlocProvider<WotdBloc>(
      create: (_) => bloc ?? (getIt<WotdBloc>()..add(const WotdEvent.started())),
      child: child,
    );
  }
}
