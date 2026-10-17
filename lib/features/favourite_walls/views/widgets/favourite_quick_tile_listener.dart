import 'dart:async';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
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
  int _generation = 0;
  Future<void> _mirrorTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionBloc>().state.session;
    _wasLoggedIn = session.loggedIn;
    _lastUserId = session.userId;
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState.status == LoadStatus.success && !session.loggedIn) _clearMirror(session.userId);
    _cache();
  }

  void _cache() {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final session = context.read<SessionBloc>().state.session;
    final favourites = context.read<FavouriteWallsBloc>().state;
    if (!session.loggedIn || session.userId != favourites.userId || favourites.status != LoadStatus.success) return;
    final int generation = ++_generation;
    _enqueue(() async {
      final paths = await OfflineAssetStore.instance.localPaths();
      if (!_isCurrent(generation, session.userId, favourites.userId)) return;
      final urls = favourites.items.map((item) => item.fullUrl).toList(growable: false);
      final selectedPaths = <String, String>{
        for (final url in urls)
          if (paths[url] case final path?) url: path,
      };
      await NativeAssetPathsStore.replaceGroup('favourites', selectedPaths);
      if (!_isCurrent(generation, session.userId, favourites.userId)) return;
      await QuickTileConfigService.pushFavWallUrls(urls);
    });
  }

  bool _isCurrent(int generation, String userId, String favouriteUserId) {
    final session = context.read<SessionBloc>().state.session;
    final favourites = context.read<FavouriteWallsBloc>().state;
    return mounted &&
        generation == _generation &&
        session.loggedIn &&
        session.userId == userId &&
        favourites.userId == favouriteUserId &&
        favourites.userId == userId &&
        favourites.status == LoadStatus.success;
  }

  void _clearMirror(String userId) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _generation++;
    _enqueue(() async {
      await NativeAssetPathsStore.clearForUser(userId);
      await QuickTileConfigService.pushFavWallUrls(const <String>[]);
    });
  }

  void _enqueue(Future<void> Function() operation) {
    _mirrorTail = _mirrorTail.then((_) => operation()).catchError((Object error, StackTrace stackTrace) {
      logger.w('Could not update favourites tile', error: error, stackTrace: stackTrace);
    });
  }

  void _onSessionChanged(SessionState current) {
    final String previousUserId = _lastUserId;
    final bool loggedOut = _wasLoggedIn && !current.session.loggedIn;
    final bool switchedAccount = _wasLoggedIn && current.session.loggedIn && _lastUserId != current.session.userId;
    _wasLoggedIn = current.session.loggedIn;
    _lastUserId = current.session.userId;
    if (loggedOut || switchedAccount) {
      _clearMirror(previousUserId);
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
