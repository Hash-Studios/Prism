import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/user_search/biz/bloc/user_search_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserSearchBuilder {
  const UserSearchBuilder._();

  static Widget withBloc({required Widget child, UserSearchBloc? bloc}) {
    return BlocProvider<UserSearchBloc>(
      create: (_) => bloc ?? getIt<UserSearchBloc>(),
      child: child,
    );
  }
}
