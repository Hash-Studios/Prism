import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteWallsBuilder {
  const FavouriteWallsBuilder._();

  static Widget withBloc({required Widget child, FavouriteWallsBloc? bloc}) {
    return BlocProvider<FavouriteWallsBloc>(
      create: (_) => bloc ?? getIt<FavouriteWallsBloc>(),
      child: child,
    );
  }
}
