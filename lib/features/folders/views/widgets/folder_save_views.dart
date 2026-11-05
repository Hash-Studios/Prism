import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/folder_save/folder_save_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

List<FolderSaveWall> folderSaveWallsOfFavourites(AppLocalizations l10n, List<FavouriteWallEntity> walls) =>
    <FolderSaveWall>[
      for (final FavouriteWallEntity wall in walls)
        if (wall is! LegacyFavouriteWall)
          FolderSaveWall(
            id: wall.id,
            source: wall.source,
            link: wall.fullUrl,
            label: wallpaperTitle(l10n, wall.toFeedItem()),
          ),
    ];

List<FolderSaveWall> folderSaveWallsOfPrism(AppLocalizations l10n, List<PrismWallpaper> walls) => <FolderSaveWall>[
  for (final PrismWallpaper wall in walls)
    FolderSaveWall(
      id: wall.id,
      source: WallpaperSource.prism,
      link: wall.fullUrl,
      label: wallpaperTitle(l10n, PrismFeedItem(id: wall.id, wallpaper: wall)),
    ),
];

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The toast for a run that ended while no folder page showed it. Built from the copy of the page that started it.
FolderSaveAnnouncer folderSaveAnnouncer(AppLocalizations l10n) => (target, run) {
  if (run.failed > 0) {
    toasts.error(l10n.foldersSaveAllToastFailed(run.failed, run.saved, target.name));
  } else {
    toasts.success(l10n.foldersSaveAllToast(run.saved, target.name));
  }
};

/// "Save all": builds the plan, shows it, and starts the run the user picks.
Future<void> openFolderSave(
  BuildContext context, {
  required FolderSaveTarget target,
  required List<FolderSaveWall> walls,
}) async {
  final FolderSaveBloc bloc = getIt<FolderSaveBloc>();
  final FolderSaveState current = bloc.state;
  if (current is FolderSaveRunning) {
    if (current.target.folderId != target.folderId) toasts.info(context.l10n.foldersSaveAllBusy);
    return;
  }
  PrismHaptics.tap();
  void plan() => bloc.add(FolderSaveEvent.planRequested(target: target, walls: walls));
  plan();
  await showPrismSheet<void>(
    context,
    builder: (_) => BlocProvider<FolderSaveBloc>.value(
      value: bloc,
      child: FolderSavePlanSheet(onRetry: plan),
    ),
  );
  final FolderSaveState after = bloc.state;
  if (after is FolderSavePlanning || after is FolderSavePlanned || after is FolderSavePlanFailed) {
    bloc.add(const FolderSaveEvent.dismissed());
  }
}

/// The plan: what Save all will do with each kind of wall, and the buttons to start it.
class FolderSavePlanSheet extends StatelessWidget {
  const FolderSavePlanSheet({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FolderSaveState state = context.watch<FolderSaveBloc>().state;
    return switch (state) {
      FolderSavePlanned(:final target, :final plan) => _planned(context, l10n, target, plan),
      FolderSavePlanFailed(:final target) => PrismSheetBody(
        title: l10n.foldersSaveAllTitle,
        message: l10n.foldersSaveAllPlanFailed,
        actions: <Widget>[PrismButton(maxLines: null, label: l10n.wallpaperTryAgain, expand: true, onPressed: onRetry)],
        child: Semantics(liveRegion: true, label: target.name, child: const SizedBox.shrink()),
      ),
      _ => PrismSheetBody(
        title: l10n.foldersSaveAllTitle,
        child: Semantics(
          liveRegion: true,
          label: l10n.foldersSaveAllChecking,
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.foldersSaveAllChecking, style: PrismTextStyles.body(context)),
              const SizedBox(height: PrismSpace.md),
              SizedBox(height: 168, child: PrismSkeleton.rows(rows: 3, avatar: false, padding: EdgeInsets.zero)),
            ],
          ),
        ),
      ),
    };
  }

  Widget _planned(BuildContext context, AppLocalizations l10n, FolderSaveTarget target, FolderSavePlan plan) {
    final int free = plan.count(FolderSaveKind.free);
    final int coins = plan.count(FolderSaveKind.coins);
    final int affordable = plan.affordable.length;
    void start(FolderSaveChoice choice) {
      PrismHaptics.impact();
      context.read<FolderSaveBloc>().add(FolderSaveEvent.started(choice: choice, announce: folderSaveAnnouncer(l10n)));
      Navigator.of(context).pop();
    }

    final List<Widget> actions = <Widget>[
      if (plan.isPro || coins == 0) ...<Widget>[
        if (free > 0)
          PrismButton(
            maxLines: null,
            key: const ValueKey<String>('folder-save-all'),
            label: l10n.foldersSaveAllCountButton(free),
            icon: Icons.download_rounded,
            expand: true,
            onPressed: () => start(FolderSaveChoice.all),
          ),
      ] else ...<Widget>[
        if (affordable > 0)
          PrismButton(
            maxLines: null,
            key: const ValueKey<String>('folder-save-paid'),
            label: l10n.foldersSaveAllPaidButton(plan.affordableCost),
            icon: Icons.download_rounded,
            expand: true,
            onPressed: () => start(FolderSaveChoice.all),
          ),
        if (free > 0)
          PrismButton(
            maxLines: null,
            key: const ValueKey<String>('folder-save-free'),
            label: l10n.foldersSaveAllFreeButton(free),
            variant: affordable > 0 ? PrismButtonVariant.tonal : PrismButtonVariant.primary,
            expand: true,
            onPressed: () => start(FolderSaveChoice.freeOnly),
          ),
      ],
    ];
    final int pro = plan.count(FolderSaveKind.proOnly);
    final int saved = plan.count(FolderSaveKind.saved);
    final int blocked = plan.blockedCount;
    return PrismSheetBody(
      title: l10n.foldersSaveAllTitle,
      actions: actions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (free > 0) _PlanRow(icon: Icons.check_circle_rounded, text: l10n.foldersSaveAllRowFree(free)),
          if (coins > 0)
            _PlanRow(icon: Icons.toll_rounded, text: l10n.foldersSaveAllRowCoins(coins, plan.account.price)),
          if (pro > 0) _PlanRow(icon: Icons.workspace_premium_rounded, text: l10n.foldersSaveAllRowPro(pro)),
          if (saved > 0) _PlanRow(icon: Icons.download_done_rounded, text: l10n.foldersSaveAllRowSaved(saved)),
          if (blocked > 0) _PlanRow(icon: Icons.block_rounded, text: l10n.foldersSaveAllRowBlocked(blocked)),
          const SizedBox(height: PrismSpace.sm),
          if (!plan.isPro && coins > 0 && affordable < coins)
            _Note(text: l10n.foldersSaveAllAffordable(affordable), emphasis: true),
          if (actions.isEmpty)
            _Note(text: l10n.foldersSaveAllNothing, emphasis: true)
          else ...<Widget>[
            _Note(
              text: _isAndroid
                  ? l10n.foldersSaveAllGalleryAlbum(target.name)
                  : l10n.foldersSaveAllPhotosAlbum(target.name),
            ),
            _Note(text: l10n.foldersSaveAllLeaveNote),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(child: Icon(icon, size: 22, color: cs.onSurfaceVariant)),
          const SizedBox(width: PrismSpace.sm),
          Expanded(child: Text(text, style: PrismTextStyles.rowTitle(context))),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.emphasis = false});

  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PrismSpace.xs),
    child: Text(text, style: emphasis ? PrismTextStyles.body(context) : PrismTextStyles.caption(context)),
  );
}

/// The progress of a run of this folder, then its summary. Empty when no run belongs to the folder.
class FolderSaveStatus extends StatelessWidget {
  const FolderSaveStatus({required this.folderId, super.key});

  final String folderId;

  @override
  Widget build(BuildContext context) =>
      getIt.isRegistered<FolderSaveBloc>() ? _FolderSaveStatusBody(folderId: folderId) : const SizedBox.shrink();
}

class _FolderSaveStatusBody extends StatefulWidget {
  const _FolderSaveStatusBody({required this.folderId});

  final String folderId;

  @override
  State<_FolderSaveStatusBody> createState() => _FolderSaveStatusState();
}

class _FolderSaveStatusState extends State<_FolderSaveStatusBody> {
  final FolderSaveBloc _bloc = getIt<FolderSaveBloc>();

  @override
  void initState() {
    super.initState();
    _bloc.watch(widget.folderId);
  }

  @override
  void didUpdateWidget(_FolderSaveStatusBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderId == widget.folderId) return;
    _bloc.unwatch(oldWidget.folderId);
    _bloc.watch(widget.folderId);
  }

  @override
  void dispose() {
    _bloc.unwatch(widget.folderId);
    super.dispose();
  }

  void _onState(BuildContext context, FolderSaveState state) {
    if (state is! FolderSaveAccessDenied || state.target.folderId != widget.folderId) return;
    if (_isAndroid) {
      toasts.error(context.l10n.wallpaperDownloadsLoadHelp);
    } else {
      showPhotosPermissionDenied(context);
    }
    _bloc.add(const FolderSaveEvent.dismissed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FolderSaveBloc, FolderSaveState>(
      bloc: _bloc,
      listener: _onState,
      builder: (context, state) {
        final bool mine = state.target?.folderId == widget.folderId;
        final Widget child = !mine
            ? const SizedBox.shrink(key: ValueKey<String>('none'))
            : switch (state) {
                FolderSaveRunning(:final run, :final cancelling) => _Progress(
                  key: const ValueKey<String>('progress'),
                  run: run,
                  cancelling: cancelling,
                  onCancel: () => _bloc.add(const FolderSaveEvent.cancelRequested()),
                ),
                FolderSaveFinished(:final run, :final cancelled) => _Summary(
                  key: const ValueKey<String>('summary'),
                  run: run,
                  cancelled: cancelled,
                  onRetry: () {
                    PrismHaptics.tap();
                    _bloc.add(FolderSaveEvent.retryRequested(announce: folderSaveAnnouncer(context.l10n)));
                  },
                  onDone: () => _bloc.add(const FolderSaveEvent.dismissed()),
                ),
                _ => const SizedBox.shrink(key: ValueKey<String>('none')),
              };
        return AnimatedSwitcher(
          duration: context.motion(PrismDurations.base),
          switchInCurve: PrismCurves.enter,
          switchOutCurve: PrismCurves.enter,
          child: child,
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.run, required this.cancelling, required this.onCancel, super.key});

  final FolderSaveRun run;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double value = run.total == 0 ? 0 : run.done / run.total;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              label: l10n.foldersSaveAllProgressSemantics(run.total, run.done),
              value: '${(value * 100).round()}%',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    cancelling ? l10n.foldersSaveAllStopping : l10n.foldersSaveAllProgress(run.done, run.total),
                    style: PrismTextStyles.rowTitle(context),
                  ),
                  const SizedBox(height: PrismSpace.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PrismRadius.pill),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      color: cs.primary,
                      backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: PrismSpace.sm),
          Tooltip(
            message: l10n.foldersSaveAllCancelHint,
            child: PrismButton(
              maxLines: null,
              key: const ValueKey<String>('folder-save-cancel'),
              label: l10n.foldersSaveAllCancel,
              variant: PrismButtonVariant.ghost,
              onPressed: cancelling ? null : onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.run, required this.cancelled, required this.onRetry, required this.onDone, super.key});

  final FolderSaveRun run;
  final bool cancelled;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<String> details = <String>[
      if (run.skipped > 0) l10n.foldersSaveAllSkipped(run.skipped),
      if (run.failed > 0) l10n.foldersSaveAllFailed(run.failed),
      if (cancelled && run.notStarted > 0) l10n.foldersSaveAllNotStarted(run.notStarted),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xs),
      child: PrismCard(
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                cancelled ? l10n.foldersSaveAllStoppedTitle(run.saved) : l10n.foldersSaveAllSavedTitle(run.saved),
                style: PrismTextStyles.cardTitle(context),
              ),
              if (details.isNotEmpty) ...<Widget>[
                const SizedBox(height: PrismSpace.xxs),
                for (final String line in details) Text(line, style: PrismTextStyles.body(context)),
              ],
              const SizedBox(height: PrismSpace.sm),
              Wrap(
                spacing: PrismSpace.xs,
                runSpacing: PrismSpace.xs,
                children: <Widget>[
                  if (run.failed > 0)
                    PrismButton(
                      maxLines: null,
                      key: const ValueKey<String>('folder-save-retry'),
                      label: l10n.foldersSaveAllRetry,
                      icon: Icons.refresh_rounded,
                      variant: PrismButtonVariant.tonal,
                      onPressed: onRetry,
                    ),
                  PrismButton(
                    maxLines: null,
                    key: const ValueKey<String>('folder-save-done'),
                    label: l10n.foldersSaveAllDone,
                    variant: PrismButtonVariant.ghost,
                    onPressed: onDone,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
