import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/auto_rotate/views/auto_rotate_entitlement.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/day_night_support.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Keeps the day and night entitlement in step with the session, and says once when Pro or the pass ends.
class DayNightSessionListener extends StatefulWidget {
  const DayNightSessionListener({required this.child, super.key});

  final Widget child;

  @override
  State<DayNightSessionListener> createState() => _DayNightSessionListenerState();
}

class _DayNightSessionListenerState extends State<DayNightSessionListener> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CoinsService.instance.passesNotifier.addListener(_onPassesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSession(context, context.read<SessionBloc>().state);
    });
    unawaited(
      dayNightSupported().then((_) {
        if (mounted) _syncSession(context, context.read<SessionBloc>().state);
      }),
    );
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
        BlocListener<DayNightBloc, DayNightState>(
          listenWhen: (previous, current) => dayNightSupportedNow && !previous.proLapsed && current.proLapsed,
          listener: (context, state) => unawaited(_showLapseToast(context)),
        ),
      ],
      child: widget.child,
    );
  }

  Future<void> _showLapseToast(BuildContext context) async {
    final AppLocalizations messages = await localizationsFor(context);
    if (!context.mounted) return;
    toasts.info(messages.dayNightOffEnded);
    context.read<DayNightBloc>().add(const DayNightEvent.proLapseAcknowledged());
  }

  void _syncSession(BuildContext context, SessionState state) {
    if (!dayNightSupportedNow || state.status != LoadStatus.success) return;
    final bool ownsPasses =
        state.session.loggedIn &&
        app_state.prismUser.loggedIn &&
        app_state.prismUser.id.trim() == state.session.userId.trim();
    final bool isPro =
        state.session.loggedIn && (state.session.premium || ownsPasses && autoRotateEntitled(state.session));
    context.read<DayNightBloc>().add(
      DayNightEvent.entitlementChanged(
        isPro: isPro,
        userId: state.session.loggedIn ? state.session.userId : '',
        passUntil: ownsPasses ? autoRotatePassEnd(state.session) : null,
      ),
    );
  }
}
