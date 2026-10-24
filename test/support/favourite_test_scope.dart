import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_local_store.dart';

class _CountsCubit extends MockCubit<Map<String, PrismWallpaperStats>> implements FavouriteCountsCubit {}

class _FavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

/// Mocks the public count boundary. Unknown counts stay unknown, rather than inventing zeroes.
void setUpFavouriteCounts({Map<String, PrismWallpaperStats> counts = const {}}) {
  setUp(() {
    final cubit = _CountsCubit();
    whenListen(cubit, const Stream<Map<String, PrismWallpaperStats>>.empty(), initialState: counts);
    getIt.registerSingleton<FavouriteCountsCubit>(cubit, dispose: (cubit) => cubit.close());
  });
  tearDown(() async {
    if (getIt.isRegistered<FavouriteCountsCubit>()) await getIt.unregister<FavouriteCountsCubit>();
    if (getIt.isRegistered<FavoritesLocalDataSource>()) await getIt.unregister<FavoritesLocalDataSource>();
  });
}

/// A real dependency boundary for grid tests which do not exercise favourite mutations.
Widget favouriteTestBuilder(BuildContext context, Widget? child) => _FavouriteTestScope(child: child!);

class _FavouriteTestScope extends StatefulWidget {
  const _FavouriteTestScope({required this.child});
  final Widget child;

  @override
  State<_FavouriteTestScope> createState() => _FavouriteTestScopeState();
}

class _FavouriteTestScopeState extends State<_FavouriteTestScope> {
  late final _FavouriteBloc bloc;

  @override
  void initState() {
    super.initState();
    if (!getIt.isRegistered<FavoritesLocalDataSource>()) {
      getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    }
    bloc = _FavouriteBloc();
    whenListen(bloc, const Stream<FavouriteWallsState>.empty(), initialState: FavouriteWallsState.initial());
  }

  @override
  void dispose() {
    bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<FavouriteWallsBloc>.value(
    value: bloc,
    child: Material(child: widget.child),
  );
}
