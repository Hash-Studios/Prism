import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/mood_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The mood chips under the For you carousel. Nothing when [moods] is empty.
class MoodChipRow extends StatelessWidget {
  const MoodChipRow({super.key, required this.moods});

  final List<MoodList> moods;

  @override
  Widget build(BuildContext context) {
    final List<MoodList> visible = moods.where((list) => list.wallIds.isNotEmpty).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.moodChipRowLabel,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.only(top: PrismSpace.xxs, bottom: PrismSpace.xs),
        // The row is 44 tall. Up to 2x text the compact label still fits its pill.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 2,
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: PrismFeedLayout.gridSpacing + PrismSpace.xxs),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final WallMood mood = visible[index].mood;
                return PrismChip(label: mood.title(l10n), compact: true, onTap: () => _open(context, mood, index));
              },
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, WallMood mood, int index) {
    if (mood == WallMood.duoReveal) unawaited(analytics.track(const DuoRowOpenedEvent(source: 'chip')));
    unawaited(analytics.track(MoodChipTappedEvent(moodId: mood.id, position: index)));
    unawaited(context.router.pushPath('/mood/${mood.id}?source=chip'));
  }
}
