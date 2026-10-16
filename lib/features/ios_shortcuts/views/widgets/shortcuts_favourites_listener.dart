import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_favourites_store.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// On iOS, keeps the favourites list that the Shortcuts intent reads in step with the signed-in user's favourites.
class ShortcutsFavouritesListener extends StatefulWidget {
  const ShortcutsFavouritesListener({required this.child, super.key});

  final Widget child;

  @override
  State<ShortcutsFavouritesListener> createState() => _ShortcutsFavouritesListenerState();
}

class _ShortcutsFavouritesListenerState extends State<ShortcutsFavouritesListener> {
  late bool _wasLoggedIn;
  late String _lastUserId;

  bool get _enabled => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    final sessionState = context.read<SessionBloc>().state;
    final session = sessionState.session;
    _wasLoggedIn = session.loggedIn;
    _lastUserId = session.userId;
    if (_enabled && _isResolvedGuest(sessionState)) _run(ShortcutsFavouritesStore.clear);
    _sync();
  }

  void _sync() {
    if (!_enabled) return;
    final session = context.read<SessionBloc>().state.session;
    final favourites = context.read<FavouriteWallsBloc>().state;
    if (!session.loggedIn || session.userId != favourites.userId || favourites.status != LoadStatus.success) return;
    _run(() => ShortcutsFavouritesStore.save(favourites.items));
  }

  bool _isResolvedGuest(SessionState state) => state.status == LoadStatus.success && !state.session.loggedIn;

  void _run(Future<void> Function() write) {
    write().catchError((Object error, StackTrace stackTrace) {
      logger.w('Could not update Shortcuts favourites', error: error, stackTrace: stackTrace);
    });
  }

  void _onSessionChanged(SessionState current) {
    final bool loggedOut = _wasLoggedIn && !current.session.loggedIn;
    final bool switchedAccount = _wasLoggedIn && current.session.loggedIn && _lastUserId != current.session.userId;
    _wasLoggedIn = current.session.loggedIn;
    _lastUserId = current.session.userId;
    if (!_enabled) return;
    if (loggedOut || switchedAccount || _isResolvedGuest(current)) {
      _run(ShortcutsFavouritesStore.clear);
    } else {
      _sync();
    }
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<SessionBloc, SessionState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.session.userId != current.session.userId ||
            previous.session.loggedIn != current.session.loggedIn,
        listener: (_, state) => _onSessionChanged(state),
      ),
      BlocListener<FavouriteWallsBloc, FavouriteWallsState>(
        listenWhen: (previous, current) =>
            previous.status != current.status || previous.userId != current.userId || previous.items != current.items,
        listener: (_, _) => _sync(),
      ),
    ],
    child: widget.child,
  );
}
