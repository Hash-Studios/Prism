import 'dart:async';

import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteQuickTileListener extends StatefulWidget {
  const FavouriteQuickTileListener({required this.child, super.key});

  final Widget child;

  @override
  State<FavouriteQuickTileListener> createState() => _FavouriteQuickTileListenerState();
}

class _FavouriteQuickTileListenerState extends State<FavouriteQuickTileListener> {
  late bool _wasLoggedIn;
  late String _lastUserId;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionBloc>().state.session;
    _wasLoggedIn = session.loggedIn;
    _lastUserId = session.userId;
    _cache();
  }

  void _cache() {
    final session = context.read<SessionBloc>().state.session;
    final favourites = context.read<FavouriteWallsBloc>().state;
    if (!session.loggedIn || session.userId != favourites.userId || favourites.status != LoadStatus.success) return;
    _push(favourites.items.map((item) => item.fullUrl).toList(growable: false));
  }

  void _push(List<String> urls) {
    unawaited(
      QuickTileConfigService.pushFavWallUrls(urls).catchError((Object error, StackTrace stackTrace) {
        logger.w('Could not update favourites tile', error: error, stackTrace: stackTrace);
      }),
    );
  }

  void _onSessionChanged(SessionState current) {
    final bool loggedOut = _wasLoggedIn && !current.session.loggedIn;
    final bool switchedAccount = _wasLoggedIn && current.session.loggedIn && _lastUserId != current.session.userId;
    _wasLoggedIn = current.session.loggedIn;
    _lastUserId = current.session.userId;
    if (loggedOut || switchedAccount) {
      _push(const <String>[]);
    } else {
      _cache();
    }
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<SessionBloc, SessionState>(
        listenWhen: (previous, current) =>
            previous.session.userId != current.session.userId || previous.session.loggedIn != current.session.loggedIn,
        listener: (_, state) => _onSessionChanged(state),
      ),
      BlocListener<FavouriteWallsBloc, FavouriteWallsState>(
        listenWhen: (previous, current) =>
            previous.status != current.status || previous.userId != current.userId || previous.items != current.items,
        listener: (_, _) => _cache(),
      ),
    ],
    child: widget.child,
  );
}
