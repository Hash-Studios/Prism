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
  @override
  void initState() {
    super.initState();
    _cache(clearIfUnavailable: true);
  }

  void _cache({bool clearIfUnavailable = false}) {
    final session = context.read<SessionBloc>().state.session;
    final favourites = context.read<FavouriteWallsBloc>().state;
    final bool sameUser = session.loggedIn && session.userId == favourites.userId;
    if (sameUser && favourites.status != LoadStatus.success && !clearIfUnavailable) return;
    final urls = sameUser && favourites.status == LoadStatus.success
        ? favourites.items.map((item) => item.fullUrl).toList(growable: false)
        : const <String>[];
    unawaited(
      QuickTileConfigService.pushFavWallUrls(urls).catchError((Object error, StackTrace stackTrace) {
        logger.w('Could not update favourites tile', error: error, stackTrace: stackTrace);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<SessionBloc, SessionState>(
        listenWhen: (previous, current) =>
            previous.session.userId != current.session.userId || previous.session.loggedIn != current.session.loggedIn,
        listener: (_, _) => _cache(clearIfUnavailable: true),
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
