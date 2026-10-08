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
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/selection_action_bar.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

enum _DownloadsStatus { loading, ready, error }

enum _DownloadSort { newest, oldest, name }

String _sortLabel(_DownloadSort sort) => switch (sort) {
  _DownloadSort.newest => 'Newest',
  _DownloadSort.oldest => 'Oldest',
  _DownloadSort.name => 'Name',
};

typedef _FileMeta = ({DateTime modified, int bytes});

/// A short size such as "820 KB" or "12.4 MB".
String _formatDownloadSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

@RoutePage()
class DownloadScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: "Downloads"),
      ),
      backgroundColor: theme.primaryColor,
      body: const SafeArea(child: DownloadsBody()),
    );
  }
}

/// The downloads list without a scaffold, so the Library tabs can host it.
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
      if (files.isNotEmpty) toasts.error("Couldn't refresh downloads. Try again.");
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

  void _toggleSelected(File file) {
    PrismHaptics.tap();
    setState(() {
      if (!_selected.remove(file.path)) _selected.add(file.path);
    });
  }

  void _exitSelection() => setState(_selected.clear);

  void _openFile(File file) {
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
              analyticsSurface: AnalyticsSurfaceValue.downloadWallpaperScreen,
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
            title: Text(paths.length == 1 ? 'Delete this download?' : 'Delete ${paths.length} downloads?'),
            content: const Text('They are removed from this device. You can download them again later.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
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
      toasts.error(failed == 1 ? "Couldn't delete 1 download." : "Couldn't delete $failed downloads.");
    }
    unawaited(readData());
  }

  Future<void> _shareSelected() async {
    final List<String> paths = _selected.toList(growable: false);
    if (paths.isEmpty) return;
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
      toasts.error("Couldn't share. Try again.");
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
    final String label = count == 1 ? '1 download' : '$count downloads';
    final int bytes = _meta.values.fold(0, (sum, meta) => sum + meta.bytes);
    return bytes > 0 ? '$label · ${_formatDownloadSize(bytes)}' : label;
  }

  Widget _toolbar(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(_summary, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
        ),
        PopupMenuButton<_DownloadSort>(
          tooltip: 'Sort downloads',
          icon: Icon(JamIcons.filter, color: theme.colorScheme.secondary),
          initialValue: _sort,
          onSelected: (sort) => setState(() => _sort = sort),
          itemBuilder: (context) => [
            for (final _DownloadSort sort in _DownloadSort.values)
              PopupMenuItem<_DownloadSort>(value: sort, child: Text(_sortLabel(sort))),
          ],
        ),
      ],
    ),
  );

  Widget _scrollable(Widget child) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: constraints.maxHeight, child: child)],
    ),
  );

  Widget _tile(BuildContext context, File file) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isSelected = _selected.contains(file.path);
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Downloaded wallpaper',
      child: Stack(
        key: ValueKey<String>(file.path),
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(image: ResizeImage(FileImage(file), width: 400), fit: BoxFit.cover),
              ),
            ),
          ),
          if (isSelected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.primary, width: 3),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.primary,
                      child: Icon(JamIcons.check, size: 16, color: scheme.onPrimary),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  splashColor: scheme.secondary.withValues(alpha: 0.3),
                  highlightColor: scheme.secondary.withValues(alpha: 0.1),
                  onTap: () => _selecting ? _toggleSelected(file) : _openFile(file),
                  onLongPress: () => _toggleSelected(file),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    switch (_status) {
      case _DownloadsStatus.loading:
        return const LoadingCards();
      case _DownloadsStatus.error:
        return _scrollable(
          GlintState(
            kind: GlintStateKind.error,
            title: "Couldn't load downloads",
            body: 'Check your storage access and try again.',
            actionLabel: 'Retry',
            onAction: () => unawaited(readData()),
          ),
        );
      case _DownloadsStatus.ready:
        if (files.isEmpty) {
          return _scrollable(
            GlintState(
              kind: GlintStateKind.empty,
              title: 'No downloads yet',
              body: 'Wallpapers you download show up here.',
              actionLabel: 'Browse wallpapers',
              onAction: () => context.router.popUntilRoot(),
            ),
          );
        }
        final List<File> sorted = _sortedFiles;
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          itemCount: sorted.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
            childAspectRatio: 0.6625,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) => _tile(context, sorted[index]),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showToolbar = _status == _DownloadsStatus.ready && files.isNotEmpty && !_selecting;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Column(
        children: [
          if (_selecting)
            SelectionHeader(count: _selected.length, onCancel: _exitSelection)
          else if (showToolbar)
            _toolbar(theme),
          Expanded(
            child: RefreshIndicator(
              backgroundColor: theme.primaryColor,
              onRefresh: () {
                PrismHaptics.impact();
                return refreshList();
              },
              child: _content(context),
            ),
          ),
          if (_selecting)
            SelectionActionBar(
              actions: [
                CircularMenuButton(
                  label: 'Delete',
                  isLoading: false,
                  onTap: () => unawaited(_deleteSelected()),
                  child: Icon(JamIcons.trash, color: theme.colorScheme.secondary, size: 20),
                ),
                if (_selected.length == 1 && !hideSetWallpaperUi)
                  SetWallpaperButton(url: _selected.first, onSet: _exitSelection),
                CircularMenuButton(
                  label: 'Share',
                  isLoading: false,
                  onTap: () => unawaited(_shareSelected()),
                  child: Icon(JamIcons.share_alt, color: theme.colorScheme.secondary, size: 20),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
