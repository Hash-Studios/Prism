import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/favourite_setups/biz/bloc/favourite_setups_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteSetupsBuilder {
  const FavouriteSetupsBuilder._();

  static Widget withBloc({required Widget child, FavouriteSetupsBloc? bloc}) {
    return BlocProvider<FavouriteSetupsBloc>(
      create: (_) => bloc ?? getIt<FavouriteSetupsBloc>(),
      child: child,
    );
  }
}
