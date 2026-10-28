import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
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

/// Asks first, then clears the history in the nearest [WallpaperHistoryBloc].
Future<void> confirmClearHistory(BuildContext context) async {
  final WallpaperHistoryBloc bloc = context.read<WallpaperHistoryBloc>();
  final int count = bloc.state.items.length;
  final bool confirmed = await showPrismConfirm(
    context,
    title: context.l10n.wallpaperClearHistoryTitle,
    message: context.l10n.wallpaperClearHistoryBody,
    confirmLabel: context.l10n.wallpaperClearHistoryAction,
    destructive: true,
  );
  if (!confirmed) return;
  PrismHaptics.tap();
  bloc.add(const WallpaperHistoryEvent.cleared());
  unawaited(analytics.track(LibraryHistoryClearedEvent(count: count)));
}

/// The Library's History tab: the wallpapers the user set, grouped by day. A tap opens the wall; the button on each
/// tile sets it again.
class WallpaperHistoryList extends StatelessWidget {
  const WallpaperHistoryList({super.key, this.now});

  /// Replaces the clock, for tests.
  final DateTime Function()? now;

  static const Set<WallpaperSource> _catalogSources = <WallpaperSource>{
    WallpaperSource.prism,
    WallpaperSource.wallhaven,
    WallpaperSource.pexels,
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
      forceSheet: true,
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
    if (id.isNotEmpty && _catalogSources.contains(source)) {
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
    final List<AppliedWallpaper> items = context.select((WallpaperHistoryBloc bloc) => bloc.state.items);
    final WallpaperHistoryBloc bloc = context.read<WallpaperHistoryBloc>();
    Future<void> refresh() async {
      bloc.add(const WallpaperHistoryEvent.started());
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: GlintState(
                  kind: GlintStateKind.empty,
                  title: context.l10n.wallpaperHistoryEmptyTitle,
                  body: context.l10n.wallpaperHistoryEmptyBody,
                  actionLabel: context.l10n.wallpaperBrowseWallpapers,
                  onAction: () =>
                      context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()])),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final Set<String> currentIds = <String>{
      ?currentWallpaperFor(items, 'home')?.id,
      ?currentWallpaperFor(items, 'lock')?.id,
    };
    final DateTime today = (now ?? DateTime.now)();
    final double footer = appliedWallpaperFooterHeight(context);
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          for (final HistoryDay group in groupHistoryByDay(items)) ...<Widget>[
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
                  return AppliedWallpaperTile(
                    key: ValueKey<String>(item.id),
                    item: item,
                    isCurrent: currentIds.contains(item.id),
                    onTap: () => unawaited(_open(context, item)),
                    onSetAgain: () => unawaited(_setAgain(context, item)),
                    onRemove: () => _remove(context, item),
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
