import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sends the user to the obsolete-version screen when bootstrap reports it after the splash was already skipped.
class ObsoleteVersionGate extends StatelessWidget {
  const ObsoleteVersionGate({super.key, required this.router, required this.child});

  final AppRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<StartupBloc, StartupState>(
      listenWhen: (previous, current) => !previous.isObsoleteVersion && current.isObsoleteVersion,
      listener: (context, state) {
        if (state.status == LoadStatus.success && router.topRoute.name != SplashWidgetRoute.name) {
          router.replaceAll([const SplashWidgetRoute()]);
        }
      },
      child: child,
    );
  }
}
