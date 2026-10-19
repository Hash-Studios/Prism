import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/views/auto_rotate_entitlement.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
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
    CoinsService.instance.passesNotifier.addListener(_onPassesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSession(context, context.read<SessionBloc>().state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CoinsService.instance.passesNotifier.removeListener(_onPassesChanged);
    super.dispose();
  }

  void _onPassesChanged() {
    if (!mounted) return;
    final SessionState session = context.read<SessionBloc>().state;
    if (session.status != LoadStatus.success ||
        !session.session.loggedIn ||
        session.session.userId.trim().isEmpty ||
        !app_state.prismUser.loggedIn ||
        app_state.prismUser.id.trim() != session.session.userId.trim()) {
      return;
    }
    _syncSession(context, session);
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
        BlocListener<AutoRotateBloc, AutoRotateState>(
          listenWhen: (previous, current) => !previous.proLapsed && current.proLapsed,
          listener: (context, state) {
            toasts.info(context.l10n.wallpaperAutoRotateOffEnded);
            context.read<AutoRotateBloc>().add(const AutoRotateEvent.proLapseAcknowledged());
          },
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
    final bool ownsPasses =
        state.session.loggedIn &&
        app_state.prismUser.loggedIn &&
        app_state.prismUser.id.trim() == state.session.userId.trim();
    final bool isPro =
        state.session.loggedIn && (state.session.premium || ownsPasses && autoRotateEntitled(state.session));
    context.read<AutoRotateBloc>().add(
      AutoRotateEvent.entitlementChanged(
        isPro: isPro,
        userId: state.session.userId,
        passUntil: ownsPasses ? autoRotatePassEnd(state.session) : null,
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
