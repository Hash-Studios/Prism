import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AutoRotateSessionListener extends StatefulWidget {
  const AutoRotateSessionListener({required this.child, super.key});

  final Widget child;

  @override
  State<AutoRotateSessionListener> createState() => _AutoRotateSessionListenerState();
}

class _AutoRotateSessionListenerState extends State<AutoRotateSessionListener> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSession(context, context.read<SessionBloc>().state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSession(context, context.read<SessionBloc>().state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionBloc, SessionState>(
          listenWhen: (previous, current) =>
              current.status == LoadStatus.success &&
              (previous.status != LoadStatus.success ||
                  previous.session.userId != current.session.userId ||
                  previous.session.loggedIn != current.session.loggedIn ||
                  previous.session.premium != current.session.premium),
          listener: (context, state) => _syncSession(context, state),
        ),
        BlocListener<FavouriteWallsBloc, FavouriteWallsState>(
          listenWhen: (previous, current) =>
              current.status == LoadStatus.success &&
              (previous.status != LoadStatus.success ||
                  previous.userId != current.userId ||
                  previous.items != current.items),
          listener: (context, state) {
            final SessionState session = context.read<SessionBloc>().state;
            if (kIsWeb ||
                defaultTargetPlatform != TargetPlatform.android ||
                session.status != LoadStatus.success ||
                !session.session.loggedIn ||
                session.session.userId != state.userId) {
              return;
            }
            context.read<AutoRotateBloc>().add(
              AutoRotateEvent.favouritesChanged(
                state.items.map((wallpaper) => wallpaper.fullUrl).toList(growable: false),
              ),
            );
          },
        ),
      ],
      child: widget.child,
    );
  }

  void _syncSession(BuildContext context, SessionState state) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || state.status != LoadStatus.success) {
      return;
    }
    context.read<AutoRotateBloc>().add(
      AutoRotateEvent.entitlementChanged(
        isPro: state.session.loggedIn && state.session.premium,
        userId: state.session.userId,
      ),
    );
    final FavouriteWallsState favourites = context.read<FavouriteWallsBloc>().state;
    if (state.session.loggedIn &&
        favourites.status == LoadStatus.success &&
        favourites.userId == state.session.userId) {
      context.read<AutoRotateBloc>().add(
        AutoRotateEvent.favouritesChanged(
          favourites.items.map((wallpaper) => wallpaper.fullUrl).toList(growable: false),
        ),
      );
    }
  }
}
