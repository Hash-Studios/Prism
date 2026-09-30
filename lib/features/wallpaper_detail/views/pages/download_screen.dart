import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DownloadScreen extends StatefulWidget {
  @override
  _DownloadScreenState createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  List<File> files = [];
  bool _loading = true;
  bool _failed = false;
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  GlobalKey<RefreshIndicatorState> refreshDownloadKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    readData();
  }

  Future<void> readData() async {
    _contentLoadTracker.start();
    List<File> found;
    bool failed = false;
    try {
      final result = await PrismMediaHostApi().listDownloads();
      if (!result.success) {
        logger.w(result.message ?? 'Unable to list downloads');
        found = <File>[];
        failed = true;
      } else {
        found = result.items.map(File.new).where((file) => file.existsSync()).toList(growable: false);
      }
    } catch (e) {
      logger.d(e.toString());
      found = <File>[];
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      files = found;
      _loading = false;
      _failed = failed;
    });
    _contentLoadTracker.success(
      itemCount: found.length,
      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
        await analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.downloadScreen,
            result: found.isEmpty ? EventResultValue.empty : EventResultValue.success,
            loadTimeMs: loadTimeMs,
            sourceContext: 'download_screen_read_data',
            itemCount: itemCount,
          ),
        );
      },
    );
  }

  Future<void> _retry() async {
    setState(() {
      files = [];
      _loading = true;
      _failed = false;
    });
    await readData();
  }

  Future<void> refreshList() async {
    refreshDownloadKey.currentState?.show();
    setState(() {
      files = [];
      _loading = true;
      _failed = false;
    });
    await readData();
  }

  void _open(File file) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.downloadScreen,
          action: AnalyticsActionValue.openDownloadedWallpaperTapped,
          sourceContext: 'download_screen_open_item',
          itemId: file.path,
        ),
      ),
    );
    context.router.push(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file));
  }

  /// Keeps a message scrollable so pull to refresh works on it.
  Widget _message(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: constraints.maxHeight, child: child),
    ),
  );

  Widget _content(BuildContext context) {
    if (_loading) return const LoadingCards();
    if (_failed) {
      return _message(
        GlintState(
          kind: GlintStateKind.error,
          title: "Couldn't load your downloads",
          body: 'Check your storage access and try again.',
          actionLabel: 'Try again',
          onAction: _retry,
        ),
      );
    }
    if (files.isEmpty) {
      return _message(
        GlintState(
          kind: GlintStateKind.empty,
          title: 'No downloads yet',
          body: 'Wallpapers you download are kept here.',
          actionLabel: 'Browse wallpapers',
          onAction: () => context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()])),
        ),
      );
    }
    return GridView.builder(
      padding: PrismWallGrid.padding.copyWith(top: PrismSpace.xs, bottom: PrismSpace.xl),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: files.length,
      gridDelegate: PrismWallGrid.delegate(context),
      itemBuilder: (context, index) => _DownloadTile(file: files[index], onTap: () => _open(files[index])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Downloads',
      body: RefreshIndicator(key: refreshDownloadKey, onRefresh: refreshList, child: _content(context)),
    );
  }
}

/// One downloaded wallpaper: a local file drawn like a [PrismWallTile].
class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.file, required this.onTap});

  final File file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PressScale(
      scale: 0.97,
      child: Semantics(
        button: true,
        image: true,
        label: 'Downloaded wallpaper',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: PrismWallGrid.tileRadius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: cs.surfaceContainerHigh),
                Image(
                  image: ResizeImage(FileImage(file), width: 400),
                  fit: BoxFit.cover,
                  frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                    duration: context.motion(PrismDurations.fast),
                    opacity: frame == null ? 0 : 1,
                    child: child,
                  ),
                  errorBuilder: (_, _, _) =>
                      Center(child: Icon(Icons.broken_image_rounded, color: cs.onSurface.withValues(alpha: 0.4))),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: PrismWallGrid.tileRadius,
                      border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
