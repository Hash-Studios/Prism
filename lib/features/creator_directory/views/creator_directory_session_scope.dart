import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/views/creator_follow_changes.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recreates creator follow state when the viewer changes accounts.
class CreatorDirectorySessionScope extends StatefulWidget {
  const CreatorDirectorySessionScope({super.key, required this.child});

  final Widget child;

  /// A local action owner survives account-driven replacement of the button that opened sign-in.
  static Future<PublicProfileBloc?> Function()? signInForFollowOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FollowBlocScope>()?.signIn;

  @override
  State<CreatorDirectorySessionScope> createState() => _CreatorDirectorySessionScopeState();
}

class _CreatorDirectorySessionScopeState extends State<CreatorDirectorySessionScope> {
  StreamSubscription<PrismUsersV2>? _sessionChanges;
  String _viewer = _currentViewer;
  int _revision = 0;
  late PublicProfileBloc _followBloc;

  static String get _currentViewer => app_state.prismUser.loggedIn ? app_state.prismUser.id : '';

  @override
  void initState() {
    super.initState();
    creatorFollowChanges.resetForViewer(_viewer);
    _followBloc = getIt<PublicProfileBloc>();
    if (getIt.isRegistered<SessionRepository>()) {
      _sessionChanges = getIt<SessionRepository>().watchCurrentUser().listen((PrismUsersV2 user) {
        final String viewer = user.loggedIn ? user.id : '';
        if (viewer == _viewer) return;
        _setViewer(viewer);
      });
    }
  }

  @override
  void dispose() {
    _sessionChanges?.cancel();
    unawaited(_followBloc.close());
    super.dispose();
  }

  void _setViewer(String viewer) {
    if (viewer == _viewer || !mounted) return;
    creatorFollowChanges.resetForViewer(viewer);
    final PublicProfileBloc previous = _followBloc;
    setState(() {
      _viewer = viewer;
      _revision++;
      _followBloc = getIt<PublicProfileBloc>();
    });
    unawaited(previous.close());
  }

  Future<PublicProfileBloc?> _signInForFollow() async {
    final int revision = _revision;
    final bool guest = _viewer.isEmpty;
    if (!mounted || !await requireSignedInAction(context)) return null;
    // Sign-in can finish before the session stream publishes its already-updated current user.
    _setViewer(_currentViewer);
    final bool sameAction = _revision == revision || (guest && _revision == revision + 1);
    return mounted && sameAction && app_state.prismUser.loggedIn ? _followBloc : null;
  }

  @override
  Widget build(BuildContext context) => _FollowBlocScope(
    signIn: _signInForFollow,
    child: KeyedSubtree(
      key: ValueKey<int>(_revision),
      child: BlocProvider<PublicProfileBloc>.value(value: _followBloc, child: widget.child),
    ),
  );
}

class _FollowBlocScope extends InheritedWidget {
  const _FollowBlocScope({required this.signIn, required super.child});

  final Future<PublicProfileBloc?> Function() signIn;

  @override
  bool updateShouldNotify(_FollowBlocScope oldWidget) => false;
}
