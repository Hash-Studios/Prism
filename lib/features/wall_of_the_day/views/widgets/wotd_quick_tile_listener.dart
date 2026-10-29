import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
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

class _WotdQuickTileListenerState extends State<WotdQuickTileListener> with WidgetsBindingObserver {
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mirror(context.read<WotdBloc>().state);
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A download can complete without a WOTD state change. Refresh before handing off to Shortcuts too.
    if (mounted && (state == AppLifecycleState.inactive || state == AppLifecycleState.resumed)) {
      _mirror(context.read<WotdBloc>().state);
    }
  }

  void _mirror(WotdState state) {
    if (state.status != LoadStatus.success) return;
    final int generation = ++_generation;
    final session = context.read<SessionBloc>().state.session;
    final String userId = session.userId;
    unawaited(_writeMirror(generation: generation, userId: userId, loggedIn: session.loggedIn, entity: state.entity));
  }

  Future<void> _writeMirror({
    required int generation,
    required String userId,
    required bool loggedIn,
    required WallOfTheDayEntity? entity,
  }) async {
    try {
      final String url = entity?.url ?? '';
      final Map<String, String> paths = await OfflineAssetStore.instance.localPaths();
      if (!_isCurrent(generation, userId, loggedIn, entity)) return;
      final String? documentId = entity?.wallDocumentId;
      final DateTime? day = entity?.featuredDayUtc;
      // A protected wall has no public URL, so its downloaded original is keyed by the wall document.
      final String assetKey = (defaultTargetPlatform == TargetPlatform.iOS || url.isEmpty) && documentId != null
          ? 'wotd:$documentId'
          : url;
      String? absolutePath = paths[url];
      if (entity != null &&
          documentId != null &&
          day != null &&
          loggedIn &&
          app_state.prismUser.loggedIn &&
          app_state.prismUser.id.trim() == userId.trim()) {
        final File? original = await getIt<DownloadedWallIndex>().localFileForIdentity(
          id: entity.wallId,
          source: entity.source,
        );
        if (!_isCurrent(generation, userId, loggedIn, entity)) return;
        if (!app_state.prismUser.loggedIn || app_state.prismUser.id.trim() != userId.trim()) return;
        absolutePath = original?.path ?? absolutePath;
      }
      Map<String, String> selected = const <String, String>{};
      if (absolutePath != null && assetKey.isNotEmpty) {
        final String nativePath;
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final support = await getApplicationSupportDirectory();
          final documents = await getApplicationDocumentsDirectory();
          if (!_isCurrent(generation, userId, loggedIn, entity)) return;
          final retainedRoot = path.join(support.path, 'prism', 'offline', 'assets');
          final downloadsRoot = path.join(documents.path, 'PrismDownloads');
          final root = path.isWithin(retainedRoot, absolutePath) ? retainedRoot : downloadsRoot;
          nativePath = path.relative(absolutePath, from: root);
          if (nativePath == '..' || nativePath.startsWith('..${path.separator}') || path.isAbsolute(nativePath)) return;
        } else {
          nativePath = absolutePath;
        }
        selected = <String, String>{assetKey: nativePath};
      }
      if (!_isCurrent(generation, userId, loggedIn, entity)) return;
      bool current() => _isCurrent(generation, userId, loggedIn, entity);
      await NativeAssetPathsStore.replaceGroup(
        'wotd',
        selected,
        isCurrent: current,
        afterReplace: () => QuickTileConfigService.pushWotdUrl(
          url,
          wallDocumentId: documentId,
          featuredDayUtc: day,
          retainedAssetKey: selected.isEmpty ? null : assetKey,
          openLink: url.isEmpty && documentId != null && entity != null
              ? Uri(
                  scheme: 'prism',
                  host: 'share',
                  queryParameters: <String, String>{
                    'id': documentId,
                    'source': 'prism',
                    'url': '',
                    'thumb': entity.thumbnailUrl,
                  },
                ).toString()
              : null,
          isCurrent: current,
        ),
      );
    } catch (error, stackTrace) {
      logger.w('Could not update Wall of the Day offline mirror', error: error, stackTrace: stackTrace);
    }
  }

  bool _isCurrent(int generation, String userId, bool loggedIn, WallOfTheDayEntity? entity) {
    if (!mounted || generation != _generation) return false;
    final session = context.read<SessionBloc>().state.session;
    if (session.userId != userId || session.loggedIn != loggedIn) {
      return false;
    }
    if (loggedIn &&
        entity?.url.isEmpty == true &&
        entity?.wallDocumentId != null &&
        (!app_state.prismUser.loggedIn || app_state.prismUser.id.trim() != userId.trim())) {
      return false;
    }
    final state = context.read<WotdBloc>().state;
    return state.status == LoadStatus.success && identical(state.entity, entity);
  }

  void _onSessionChanged(SessionState state) {
    final generation = ++_generation;
    unawaited(_clearThenRemirror(state, generation));
  }

  Future<void> _clearThenRemirror(SessionState state, int generation) async {
    try {
      await NativeAssetPathsStore.replaceGroup(
        'wotd',
        const <String, String>{},
        afterReplace: () => QuickTileConfigService.pushWotdUrl(''),
      );
      if (mounted && generation == _generation && state.session.loggedIn) _mirror(context.read<WotdBloc>().state);
    } catch (error, stackTrace) {
      logger.w('Could not update Wall of the Day offline mirror', error: error, stackTrace: stackTrace);
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
      BlocListener<WotdBloc, WotdState>(
        listenWhen: (previous, current) =>
            current.status == LoadStatus.success &&
            (previous.status != LoadStatus.success || !identical(previous.entity, current.entity)),
        listener: (_, state) => _mirror(state),
      ),
    ],
    child: widget.child,
  );
}
