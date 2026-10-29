import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/selection_action_bar.dart';
import 'package:Prism/features/library/views/widgets/library_toolbar.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

enum _DownloadsStatus { loading, ready, error }

enum _DownloadSort { newest, oldest, name }

String _sortLabel(AppLocalizations l10n, _DownloadSort sort) => switch (sort) {
  _DownloadSort.newest => l10n.wallpaperDownloadSortNewest,
  _DownloadSort.oldest => l10n.wallpaperDownloadSortOldest,
  _DownloadSort.name => l10n.wallpaperDownloadSortName,
};

typedef _FileMeta = ({DateTime modified, int bytes});

/// A short size such as "820 KB" or "12.4 MB".
String _formatDownloadSize(AppLocalizations l10n, int bytes) {
  final NumberFormat number = NumberFormat.decimalPattern(l10n.localeName);
  if (bytes < 1024) return '${number.format(bytes)} B';
  if (bytes < 1024 * 1024) return '${number.format((bytes / 1024).round())} KB';
  if (bytes < 1024 * 1024 * 1024) return '${number.format(bytes / (1024 * 1024))} MB';
  return '${number.format(bytes / (1024 * 1024 * 1024))} GB';
}

/// The picture a download tile draws. Opening the tile reads its shape from the same decode.
ImageProvider _tilePicture(File file) => ResizeImage(FileImage(file), width: 400);

/// Width over height of [picture] when it is already decoded, else null. It reads the image cache and never waits.
@visibleForTesting
double? decodedAspectRatio(ImageProvider picture) {
  double? ratio;
  final ImageStreamListener listener = ImageStreamListener((ImageInfo info, bool _) {
    if (info.image.height > 0) ratio = info.image.width / info.image.height;
    info.dispose();
  });
  // A decoded picture calls the listener at once. A picture that is not decoded yet does not, and stays null.
  picture.resolve(ImageConfiguration.empty)
    ..addListener(listener)
    ..removeListener(listener);
  return ratio;
}

@RoutePage()
class DownloadScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PrismPage(
    title: context.l10n.wallpaperDownloadsTitle,
    maxContentWidth: double.infinity,
    body: const DownloadsBody(),
  );
}

/// The downloads list without a page frame, so the Library tabs can host it.
class DownloadsBody extends StatefulWidget {
  const DownloadsBody({super.key});

  @override
  State<DownloadsBody> createState() => _DownloadsBodyState();
}

class _DownloadsBodyState extends State<DownloadsBody> {
  List<File> files = [];
  Map<String, _FileMeta> _meta = <String, _FileMeta>{};
  _DownloadSort _sort = _DownloadSort.newest;
  _DownloadsStatus _status = _DownloadsStatus.loading;
  final Set<String> _selected = <String>{};
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    readData();
  }

  Future<void> readData() async {
    _contentLoadTracker.start();
    List<File>? found;
    try {
      final result = await PrismMediaHostApi().listDownloads();
      if (!result.success) {
        logger.w(result.message ?? 'Unable to list downloads');
      } else {
        found = result.items.map(File.new).where((file) => file.existsSync()).toList(growable: false);
      }
    } catch (e) {
      logger.d(e.toString());
    }
    if (!mounted) return;
    final Map<String, _FileMeta> meta = <String, _FileMeta>{};
    for (final File file in found ?? const <File>[]) {
      try {
        final FileStat stat = file.statSync();
        meta[file.path] = (modified: stat.modified, bytes: stat.size);
      } catch (error) {
        logger.d('Could not read the size of ${file.path}: $error');
      }
    }
    if (found == null) {
      if (files.isNotEmpty) toasts.error(context.l10n.wallpaperDownloadsRefreshError);
      setState(() => _status = files.isEmpty ? _DownloadsStatus.error : _DownloadsStatus.ready);
    } else {
      final Set<String> paths = found.map((file) => file.path).toSet();
      setState(() {
        files = found!;
        _meta = meta;
        _status = _DownloadsStatus.ready;
        _selected.removeWhere((path) => !paths.contains(path));
      });
    }
    _contentLoadTracker.success(
      itemCount: found?.length ?? 0,
      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
        await analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.downloadScreen,
            result: found == null
                ? EventResultValue.failure
                : found.isEmpty
                ? EventResultValue.empty
                : EventResultValue.success,
            loadTimeMs: loadTimeMs,
            sourceContext: 'download_screen_read_data',
            itemCount: itemCount,
          ),
        );
      },
    );
  }

  Future<void> refreshList() => readData();

  Future<void> _retry() {
    setState(() => _status = _DownloadsStatus.loading);
    return readData();
  }

  void _toggleSelected(File file) {
    PrismHaptics.tap();
    setState(() {
      if (!_selected.remove(file.path)) _selected.add(file.path);
    });
  }

  void _exitSelection() => setState(_selected.clear);

  void _openFile(File file, String heroTag) {
    PrismHaptics.tap();
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
    final DownloadedWallRef? wall = getIt<DownloadedWallIndex>().resolve(file.path);
    context.router.push(
      wall == null
          ? DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file)
          : WallpaperDetailRoute(
              wallId: wall.id,
              source: wall.source,
              localFile: file,
              // The tile already knows the picture's shape, so the card opens at it and does not jump on load.
              aspectRatio: decodedAspectRatio(_tilePicture(file)),
              analyticsSurface: AnalyticsSurfaceValue.downloadWallpaperScreen,
              heroTag: heroTag,
            ),
    );
  }

  Future<void> _deleteSelected() async {
    final List<String> paths = _selected.toList(growable: false);
    if (paths.isEmpty) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              paths.length == 1
                  ? context.l10n.wallpaperDeleteOneDownloadTitle
                  : context.l10n.wallpaperDeleteManyDownloadsTitle(paths.length),
            ),
            content: Text(
              paths.length == 1
                  ? context.l10n.wallpaperDeleteOneDownloadBody
                  : context.l10n.wallpaperDeleteManyDownloadsBody,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.actionCancel)),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.l10n.wallpaperDelete)),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    PrismHaptics.tap();
    final Set<String> deleted = <String>{};
    final api = PrismMediaHostApi();
    for (final String path in paths) {
      try {
        final result = await api.deleteDownload(path);
        if (result.success) {
          deleted.add(path);
        } else {
          logger.w(result.message ?? 'Unable to delete download');
        }
      } catch (error, stackTrace) {
        logger.e('Unable to delete download', error: error, stackTrace: stackTrace);
      }
    }
    if (!mounted) return;
    setState(() {
      files = files.where((file) => !deleted.contains(file.path)).toList(growable: false);
      _selected.removeAll(deleted);
    });
    if (deleted.isNotEmpty) {
      await getIt<DownloadedWallIndex>().forget(deleted, remainingPaths: files.map((file) => file.path));
      if (!mounted) return;
    }
    if (deleted.length < paths.length) {
      final int failed = paths.length - deleted.length;
      toasts.error(context.l10n.wallpaperDownloadsDeleteError(failed));
    }
    unawaited(readData());
  }

  Future<void> _shareSelected() async {
    final List<String> paths = _selected.toList(growable: false);
    if (paths.isEmpty) return;
    final AppLocalizations l10n = context.l10n;
    PrismHaptics.tap();
    final RenderObject? box = context.findRenderObject();
    final Rect origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: paths.map(XFile.new).toList(growable: false),
          sharePositionOrigin: origin.isEmpty ? const Rect.fromLTWH(1, 1, 1, 1) : origin,
        ),
      );
    } catch (error, stackTrace) {
      logger.e('Could not share downloads', error: error, stackTrace: stackTrace);
      toasts.error(l10n.wallpaperDownloadsShareError);
    }
  }

  List<File> get _sortedFiles {
    final List<MapEntry<int, File>> indexed = files.asMap().entries.toList();
    DateTime modified(File file) => _meta[file.path]?.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
    int byName(File a, File b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
    indexed.sort((a, b) {
      final int order = switch (_sort) {
        _DownloadSort.newest => modified(b.value).compareTo(modified(a.value)),
        _DownloadSort.oldest => modified(a.value).compareTo(modified(b.value)),
        _DownloadSort.name => byName(a.value, b.value),
      };
      return order != 0 ? order : a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  String get _summary {
    final int count = files.length;
    final String label = context.l10n.wallpaperDownloadCount(count);
    final int bytes = _meta.values.fold(0, (sum, meta) => sum + meta.bytes);
    return bytes > 0 ? '$label · ${_formatDownloadSize(context.l10n, bytes)}' : label;
  }

  Widget _toolbar(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return LibraryToolbar(
      leading: Text(_summary, style: PrismTextStyles.caption(context)),
      actions: <Widget>[
        PopupMenuButton<_DownloadSort>(
          tooltip: context.l10n.wallpaperSortDownloads,
          icon: Icon(Icons.sort_rounded, color: cs.onSurface),
          initialValue: _sort,
          onSelected: (sort) => setState(() => _sort = sort),
          itemBuilder: (context) => <PopupMenuEntry<_DownloadSort>>[
            for (final _DownloadSort sort in _DownloadSort.values)
              PopupMenuItem<_DownloadSort>(value: sort, child: Text(_sortLabel(context.l10n, sort))),
          ],
        ),
      ],
    );
  }

  /// Keeps a message scrollable so pull to refresh works on it.
  Widget _message(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: constraints.maxHeight, child: child),
    ),
  );

  Widget _content(BuildContext context) {
    switch (_status) {
      case _DownloadsStatus.loading:
        return const LoadingCards();
      case _DownloadsStatus.error:
        return _message(
          GlintState(
            kind: GlintStateKind.error,
            title: context.l10n.wallpaperDownloadsLoadError,
            body: context.l10n.wallpaperDownloadsLoadHelp,
            actionLabel: context.l10n.wallpaperTryAgain,
            onAction: () => unawaited(_retry()),
          ),
        );
      case _DownloadsStatus.ready:
        if (files.isEmpty) {
          return _message(
            GlintState(
              kind: GlintStateKind.empty,
              title: context.l10n.wallpaperDownloadsEmptyTitle,
              body: context.l10n.wallpaperDownloadsEmptyBody,
              actionLabel: context.l10n.wallpaperBrowseWallpapers,
              onAction: () => context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()])),
            ),
          );
        }
        final List<File> sorted = _sortedFiles;
        return GridView.builder(
          padding: PrismWallGrid.padding.copyWith(top: PrismSpace.xs, bottom: PrismSpace.xl),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: sorted.length,
          gridDelegate: PrismWallGrid.delegate(context),
          itemBuilder: (context, index) {
            final File file = sorted[index];
            final String heroTag = prismHeroTag(
              Scrollable.maybeOf(context) ?? context,
              index,
              'download-${p.basename(file.path)}-${file.path.hashCode}',
            );
            return _DownloadTile(
              key: ValueKey<String>(sorted[index].path),
              file: file,
              selected: _selected.contains(file.path),
              heroTag: _selecting ? null : heroTag,
              onTap: () => _selecting ? _toggleSelected(file) : _openFile(file, heroTag),
              onLongPress: () => _toggleSelected(file),
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool showToolbar = _status == _DownloadsStatus.ready && files.isNotEmpty && !_selecting;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Column(
        children: <Widget>[
          if (_selecting)
            SelectionHeader(count: _selected.length, onCancel: _exitSelection)
          else if (showToolbar)
            _toolbar(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                PrismHaptics.impact();
                return refreshList();
              },
              child: _content(context),
            ),
          ),
          if (_selecting)
            SelectionActionBar(
              actions: <Widget>[
                CircularMenuButton(
                  label: context.l10n.wallpaperDelete,
                  isLoading: false,
                  onTap: () => unawaited(_deleteSelected()),
                  child: Icon(Icons.delete_outline_rounded, color: cs.onSurface, size: 20),
                ),
                if (_selected.length == 1 && !hideSetWallpaperUi)
                  SetWallpaperButton(url: _selected.first, onSet: _exitSelection, entryPoint: 'downloads'),
                CircularMenuButton(
                  label: context.l10n.wallpaperShare,
                  isLoading: false,
                  onTap: () => unawaited(_shareSelected()),
                  child: Icon(Icons.ios_share_rounded, color: cs.onSurface, size: 20),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One downloaded wallpaper: a local file drawn like a [PrismWallTile]. A long press selects it.
class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    super.key,
    required this.file,
    required this.selected,
    required this.heroTag,
    required this.onTap,
    required this.onLongPress,
  });

  final File file;
  final bool selected;
  final String? heroTag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget image = Image(
      image: _tilePicture(file),
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, sync) =>
          AnimatedOpacity(duration: context.motion(PrismDurations.fast), opacity: frame == null ? 0 : 1, child: child),
      errorBuilder: (_, _, _) =>
          Center(child: Icon(Icons.broken_image_rounded, color: cs.onSurface.withValues(alpha: 0.4))),
    );
    return PressScale(
      scale: 0.97,
      child: Semantics(
        button: true,
        image: true,
        selected: selected,
        label: context.l10n.wallpaperDownloadedWallpaper,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: ClipRRect(
            borderRadius: PrismWallGrid.tileRadius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: cs.surfaceContainerHigh),
                if (heroTag == null)
                  image
                else
                  Hero(tag: heroTag!, createRectTween: wallpaperHeroRectTween, child: image),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected ? cs.primary.withValues(alpha: 0.25) : null,
                      borderRadius: PrismWallGrid.tileRadius,
                      border: Border.all(
                        color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? Align(
                            alignment: AlignmentDirectional.topEnd,
                            child: Padding(
                              padding: const EdgeInsets.all(PrismSpace.xs),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: cs.primary,
                                child: Icon(Icons.check_rounded, size: 16, color: cs.onPrimary),
                              ),
                            ),
                          )
                        : null,
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
