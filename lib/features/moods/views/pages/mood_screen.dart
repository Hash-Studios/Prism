import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:Prism/features/moods/biz/mood_walls_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/mood_copy.dart';
import 'package:Prism/features/moods/views/widgets/wall_ids_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The walls of one Home mood, ordered by the user's taste.
@RoutePage()
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key, @PathParam('moodId') required this.moodId, @QueryParam('source') this.source = 'link'});

  final String moodId;

  /// Where the user opened the page: 'chip', 'row' or 'link'. For analytics.
  final String source;

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  WallMood? get _mood => WallMood.parse(widget.moodId);
  MoodWallsCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(MoodScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The router can reuse this page for another mood.
    if (oldWidget.moodId == widget.moodId) return;
    unawaited(_cubit?.close());
    _cubit = null;
    _open();
  }

  void _open() {
    final WallMood? mood = _mood;
    if (mood == null) return;
    _cubit = getIt<MoodWallsCubit>();
    unawaited(_cubit!.load(mood));
    unawaited(analytics.track(MoodPageOpenedEvent(moodId: widget.moodId, source: widget.source)));
  }

  @override
  void dispose() {
    unawaited(_cubit?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final WallMood? mood = _mood;
    return PrismPage(
      title: mood?.title(l10n) ?? l10n.moodEmptyTitle,
      body: mood == null || _cubit == null
          ? GlintState(kind: GlintStateKind.empty, title: l10n.moodEmptyTitle, body: l10n.moodEmptyBody)
          : BlocBuilder<MoodWallsCubit, MoodWallsState>(
              bloc: _cubit,
              builder: (context, state) => _body(context, mood, state),
            ),
    );
  }

  Widget _body(BuildContext context, WallMood mood, MoodWallsState state) {
    final l10n = context.l10n;
    switch (state) {
      case MoodWallsLoading():
        return const LoadingCards(useFeedLayout: true);
      case MoodWallsFailed():
        return GlintState(
          kind: GlintStateKind.error,
          title: l10n.moodLoadError,
          body: l10n.wallpaperCheckConnection,
          actionLabel: l10n.wallpaperTryAgain,
          onAction: () => unawaited(_cubit!.load(mood)),
        );
      case MoodWallsLoaded(:final walls) when walls.isEmpty:
        return GlintState(kind: GlintStateKind.empty, title: l10n.moodEmptyTitle, body: l10n.moodEmptyBody);
      case MoodWallsLoaded(:final walls):
        return WallIdsGrid(walls: walls, header: mood.body(l10n));
    }
  }
}
