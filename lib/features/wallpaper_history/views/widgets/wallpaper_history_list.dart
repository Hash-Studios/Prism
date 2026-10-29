import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

typedef HistoryDay = ({DateTime day, List<AppliedWallpaper> items});

/// [newestFirst] split into local calendar days, newest day first. Each day keeps the list order.
List<HistoryDay> groupHistoryByDay(List<AppliedWallpaper> newestFirst) {
  final List<HistoryDay> days = <HistoryDay>[];
  for (final AppliedWallpaper item in newestFirst) {
    final DateTime local = item.appliedAt.toLocal();
    final DateTime day = DateTime(local.year, local.month, local.day);
    if (days.isEmpty || days.last.day != day) {
      days.add((day: day, items: <AppliedWallpaper>[item]));
    } else {
      days.last.items.add(item);
    }
  }
  return days;
}

/// "Today", "Yesterday", a weekday and date this year, or a full date before that.
String historyDayLabel(AppLocalizations l10n, DateTime day, DateTime now) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  if (day.year == today.year && day.month == today.month && day.day == today.day) return l10n.notifToday;
  final DateTime yesterday = DateTime(today.year, today.month, today.day - 1);
  if (day.year == yesterday.year && day.month == yesterday.month && day.day == yesterday.day) {
    return l10n.notifYesterday;
  }
  return day.year == now.year
      ? DateFormat.MMMEd(l10n.localeName).format(day)
      : DateFormat.yMMMEd(l10n.localeName).format(day);
}

enum HistorySegment { setAndDownloaded, viewed }

/// Asks first, then clears one list in the nearest [WallpaperHistoryBloc].
Future<void> confirmClearHistory(BuildContext context, HistorySegment segment) async {
  final WallpaperHistoryBloc bloc = context.read<WallpaperHistoryBloc>();
  final AppLocalizations l10n = context.l10n;
  final bool viewed = segment == HistorySegment.viewed;
  final int count = viewed ? bloc.state.viewed.length : bloc.state.items.length;
  final bool confirmed = await showPrismConfirm(
    context,
    title: viewed ? l10n.historyClearViewedTitle : l10n.wallpaperClearHistoryTitle,
    message: viewed ? l10n.historyClearViewedBody : l10n.historyClearSyncedBody,
    confirmLabel: viewed ? l10n.historyClearViewedAction : l10n.wallpaperClearHistoryAction,
    destructive: true,
  );
  if (!confirmed) return;
  PrismHaptics.tap();
  if (viewed) {
    bloc.add(const WallpaperHistoryEvent.viewedCleared());
    unawaited(analytics.track(RecentlyViewedClearedEvent(count: count)));
  } else {
    bloc.add(const WallpaperHistoryEvent.cleared());
    unawaited(analytics.track(LibraryHistoryClearedEvent(count: count)));
  }
}

/// A recently viewed wall as a tile row. It opens the detail screen.
AppliedWallpaper _viewedRow(HistoryWall wall) => AppliedWallpaper(
  id: 'viewed:${wall.key}',
  source: wall.source.wireValue,
  thumbnailUrl: wall.thumbnailUrl,
  fullUrl: '',
  target: HistoryAction.view.name,
  appliedAt: wall.at,
  wallpaperId: wall.id,
);

/// The Library's History tab: walls set or downloaded (synced to the account), and walls viewed on this device. Both
/// are grouped by day. A tap opens the wall; on Android the button on a set tile sets it again.
class WallpaperHistoryList extends StatefulWidget {
  const WallpaperHistoryList({super.key, this.now, this.canSetWallpaper, this.signedIn});

  /// Replaces the clock, for tests.
  final DateTime Function()? now;

  /// Replaces the platform check, for tests. iOS cannot set wallpapers, so its first list is Downloaded.
  final bool? canSetWallpaper;

  /// Replaces the signed-in check, for tests.
  final bool? signedIn;

  @override
  State<WallpaperHistoryList> createState() => _WallpaperHistoryListState();
}

class _WallpaperHistoryListState extends State<WallpaperHistoryList> {
  HistorySegment _segment = HistorySegment.setAndDownloaded;

  bool get _canSet => widget.canSetWallpaper ?? !hideSetWallpaperUi;

  String _segmentLabel(AppLocalizations l10n, HistorySegment segment) => switch (segment) {
    HistorySegment.setAndDownloaded => _canSet ? l10n.historySetAndDownloaded : l10n.historyDownloaded,
    HistorySegment.viewed => l10n.historyRecentlyViewed,
  };

  static File? _localFile(String path) {
    final String filePath = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
    if (!filePath.startsWith('/')) return null;
    final File file = File(filePath);
    return file.existsSync() ? file : null;
  }

  Future<void> _setAgain(BuildContext context, AppliedWallpaper item) async {
    PrismHaptics.tap();
    unawaited(analytics.track(LibraryHistorySetAgainEvent(provider: item.source, target: item.target)));
    final WallpaperHistoryBloc bloc = context.read<WallpaperHistoryBloc>();
    await SetWallpaperFlow.run(
      context,
      url: item.fullUrl,
      thumbnailUrl: item.thumbnailUrl,
      forceScreen: true,
      entryPoint: 'wallpaper_history',
      wallpaperId: item.wallpaperId,
      wallpaperSource: WallpaperSourceX.fromWire(item.source),
    );
    if (!bloc.isClosed) bloc.add(const WallpaperHistoryEvent.started());
  }

  /// Opens the catalogue wall, or the local file for a wall that has no catalogue id. A wall that is neither
  /// (its file is gone) opens the set sheet, which still has its image.
  Future<void> _open(BuildContext context, AppliedWallpaper item) async {
    final WallpaperHistoryBloc bloc = context.read<WallpaperHistoryBloc>();
    final StackRouter router = context.router;
    final WallpaperSource source = WallpaperSourceX.fromWire(item.source);
    final String id = item.wallpaperId ?? '';
    if (id.isNotEmpty && HistoryWall.catalogSources.contains(source)) {
      PrismHaptics.tap();
      await router.push(WallpaperDetailRoute(wallId: id, source: source, thumbnailUrl: item.thumbnailUrl));
    } else {
      final File? file = _localFile(item.fullUrl);
      if (file == null) {
        await _setAgain(context, item);
        return;
      }
      PrismHaptics.tap();
      await router.push(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file));
    }
    if (!bloc.isClosed) bloc.add(const WallpaperHistoryEvent.started());
  }

  void _remove(BuildContext context, AppliedWallpaper item) {
    PrismHaptics.tap();
    final WallpaperHistoryBloc bloc = context.read<WallpaperHistoryBloc>();
    bloc.add(WallpaperHistoryEvent.removed(item.id));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.wallpaperRemovedFromHistory),
          action: SnackBarAction(label: context.l10n.coreUndo, onPressed: () => unawaited(bloc.restore(item))),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final WallpaperHistoryState state = context.select((WallpaperHistoryBloc bloc) => bloc.state);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(PrismWallGrid.margin, PrismSpace.sm, PrismWallGrid.margin, 0),
          child: PrismSegmented<HistorySegment>(
            values: HistorySegment.values,
            selected: _segment,
            labelOf: (segment) => _segmentLabel(context.l10n, segment),
            onChanged: (segment) {
              if (segment == _segment) return;
              PrismHaptics.selection();
              setState(() => _segment = segment);
            },
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: context.motion(PrismDurations.fast),
            switchInCurve: PrismCurves.enter,
            switchOutCurve: PrismCurves.enter,
            child: KeyedSubtree(
              key: ValueKey<HistorySegment>(_segment),
              child: switch (_segment) {
                HistorySegment.setAndDownloaded => _list(
                  context,
                  rows: state.items,
                  note: (widget.signedIn ?? app_state.prismUser.loggedIn)
                      ? context.l10n.historySyncedNote
                      : context.l10n.historySyncedNoteGuest,
                  empty: GlintState(
                    kind: GlintStateKind.empty,
                    title: context.l10n.wallpaperHistoryEmptyTitle,
                    body: _canSet ? context.l10n.historyEmptyBodyAndroid : context.l10n.historyEmptyBodyIos,
                    actionLabel: context.l10n.wallpaperBrowseWallpapers,
                    onAction: () => _browse(context),
                  ),
                ),
                HistorySegment.viewed => _list(
                  context,
                  rows: state.viewed.map(_viewedRow).toList(growable: false),
                  empty: state.viewingHistoryOn
                      ? GlintState(
                          kind: GlintStateKind.empty,
                          title: context.l10n.historyViewedEmptyTitle,
                          body: context.l10n.historyViewedEmptyBody,
                          actionLabel: context.l10n.wallpaperBrowseWallpapers,
                          onAction: () => _browse(context),
                        )
                      : GlintState(
                          kind: GlintStateKind.empty,
                          title: context.l10n.historyViewedOffTitle,
                          body: context.l10n.historyViewedOffBody,
                          actionLabel: context.l10n.historyViewedOffAction,
                          onAction: () {
                            PrismHaptics.tap();
                            context.read<WallpaperHistoryBloc>().add(const WallpaperHistoryEvent.viewingTurnedOn());
                            unawaited(analytics.track(const ViewingHistoryToggledEvent(value: true)));
                          },
                        ),
                ),
              },
            ),
          ),
        ),
      ],
    );
  }

  void _browse(BuildContext context) =>
      context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()]));

  Widget _list(BuildContext context, {required List<AppliedWallpaper> rows, required Widget empty, String? note}) {
    final WallpaperHistoryBloc bloc = context.read<WallpaperHistoryBloc>();
    Future<void> refresh() async {
      bloc.add(const WallpaperHistoryEvent.started());
    }

    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismWallGrid.margin + PrismSpace.xxs,
        PrismSpace.xs,
        PrismWallGrid.margin - PrismSpace.xs,
        0,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: note == null ? const SizedBox.shrink() : Text(note, style: PrismTextStyles.caption(context))),
          if (rows.isNotEmpty)
            PrismButton(
              key: ValueKey<String>('history-clear-${_segment.name}'),
              label: context.l10n.wallpaperClear,
              variant: PrismButtonVariant.ghost,
              size: PrismButtonSize.compact,
              onPressed: () => unawaited(confirmClearHistory(context, _segment)),
            ),
        ],
      ),
    );
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(child: header),
            // Centred in the space left, and free to grow taller than it at large text sizes.
            SliverLayoutBuilder(
              builder: (context, constraints) => SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.remainingPaintExtent),
                  child: Center(child: empty),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final Set<String> currentIds = <String>{
      ?currentWallpaperFor(rows, 'home')?.id,
      ?currentWallpaperFor(rows, 'lock')?.id,
    };
    final DateTime today = (widget.now ?? DateTime.now)();
    final double footer = appliedWallpaperFooterHeight(context);
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(child: header),
          for (final HistoryDay group in groupHistoryByDay(rows)) ...<Widget>[
            SliverToBoxAdapter(
              child: PrismSectionHeader(
                title: historyDayLabel(context.l10n, group.day, today),
                small: true,
                padding: const EdgeInsets.fromLTRB(
                  PrismWallGrid.margin + PrismSpace.xxs,
                  PrismSpace.md,
                  PrismWallGrid.margin,
                  PrismSpace.xs,
                ),
              ),
            ),
            SliverPadding(
              padding: PrismWallGrid.padding,
              sliver: SliverGrid.builder(
                gridDelegate: PrismWallGrid.delegate(context, footerHeight: footer),
                itemCount: group.items.length,
                itemBuilder: (context, index) {
                  final AppliedWallpaper item = group.items[index];
                  final bool local = item.fullUrl.isNotEmpty;
                  return AppliedWallpaperTile(
                    key: ValueKey<String>(item.id),
                    item: item,
                    isCurrent: currentIds.contains(item.id),
                    onTap: () => unawaited(_open(context, item)),
                    onSetAgain: local ? () => unawaited(_setAgain(context, item)) : null,
                    onRemove: _segment == HistorySegment.viewed ? null : () => _remove(context, item),
                  );
                },
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + PrismSpace.xl)),
        ],
      ),
    );
  }
}
