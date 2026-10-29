import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/wall_requests/biz/wall_requests_cubit.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class WallRequestsPage extends StatelessWidget implements AutoRouteWrapper {
  const WallRequestsPage({super.key, @QueryParam('tab') this.tab = 'top'});

  final String tab;

  @override
  Widget wrappedRoute(BuildContext context) =>
      BlocProvider<WallRequestsCubit>(create: (_) => getIt<WallRequestsCubit>(), child: this);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
