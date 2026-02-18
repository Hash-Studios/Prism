import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/quick_actions/biz/bloc/quick_actions_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class QuickActionsBuilder {
  const QuickActionsBuilder._();

  static Widget withBloc({required Widget child, QuickActionsBloc? bloc}) {
    return BlocProvider<QuickActionsBloc>(create: (_) => bloc ?? getIt<QuickActionsBloc>(), child: child);
  }
}
