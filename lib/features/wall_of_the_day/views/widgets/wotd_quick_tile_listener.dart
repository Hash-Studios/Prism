import 'dart:async';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class WotdQuickTileListener extends StatefulWidget {
  const WotdQuickTileListener({required this.child, super.key});

  final Widget child;

  @override
  State<WotdQuickTileListener> createState() => _WotdQuickTileListenerState();
}

class _WotdQuickTileListenerState extends State<WotdQuickTileListener> {
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _mirror(context.read<WotdBloc>().state);
  }

  void _mirror(WotdState state) {
    if (state.status != LoadStatus.success) return;
    final int generation = ++_generation;
    final session = context.read<SessionBloc>().state.session;
    final String userId = session.userId;
    final String url = state.entity?.url ?? '';
    unawaited(_writeMirror(generation: generation, userId: userId, loggedIn: session.loggedIn, url: url));
  }

  Future<void> _writeMirror({
    required int generation,
    required String userId,
    required bool loggedIn,
    required String url,
  }) async {
    try {
      final Map<String, String> paths = await OfflineAssetStore.instance.localPaths();
      if (!_isCurrent(generation, userId, loggedIn, url)) return;
      final String? absolutePath = paths[url];
      Map<String, String> selected = const <String, String>{};
      if (absolutePath != null && url.isNotEmpty) {
        final String nativePath;
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final support = await getApplicationSupportDirectory();
          final retainedRoot = path.join(support.path, 'prism', 'offline', 'assets');
          nativePath = path.relative(absolutePath, from: retainedRoot);
          if (nativePath == '..' || nativePath.startsWith('..${path.separator}') || path.isAbsolute(nativePath)) return;
        } else {
          nativePath = absolutePath;
        }
        selected = <String, String>{url: nativePath};
      }
      await NativeAssetPathsStore.replaceGroup('wotd', selected);
      if (!_isCurrent(generation, userId, loggedIn, url)) return;
      await QuickTileConfigService.pushWotdUrl(url);
    } catch (error, stackTrace) {
      logger.w('Could not update Wall of the Day offline mirror', error: error, stackTrace: stackTrace);
    }
  }

  bool _isCurrent(int generation, String userId, bool loggedIn, String url) {
    final session = context.read<SessionBloc>().state.session;
    if (!mounted || generation != _generation || session.userId != userId || session.loggedIn != loggedIn) {
      return false;
    }
    final state = context.read<WotdBloc>().state;
    return state.status == LoadStatus.success && (state.entity?.url ?? '') == url;
  }

  void _onSessionChanged(SessionState state) {
    _generation++;
    unawaited(NativeAssetPathsStore.replaceGroup('wotd', const <String, String>{}));
    if (state.session.loggedIn) _mirror(context.read<WotdBloc>().state);
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<SessionBloc, SessionState>(
        listenWhen: (previous, current) =>
            previous.session.userId != current.session.userId || previous.session.loggedIn != current.session.loggedIn,
        listener: (_, state) => _onSessionChanged(state),
      ),
      BlocListener<WotdBloc, WotdState>(
        listenWhen: (previous, current) =>
            current.status == LoadStatus.success &&
            (previous.status != LoadStatus.success || previous.entity?.url != current.entity?.url),
        listener: (_, state) => _mirror(state),
      ),
    ],
    child: widget.child,
  );
}
