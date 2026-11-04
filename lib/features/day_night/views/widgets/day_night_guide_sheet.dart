import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_phone_preview.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Shortcuts steps that switch the day and night walls at the times in [pair].
Future<void> showDayNightGuideSheet(BuildContext context, {required DayNightPair pair}) {
  unawaited(analytics.track(const DayNightIosGuideOpenedEvent()));
  return showPrismSheet<void>(context, builder: (_) => _DayNightGuideSheet(pair: pair));
}

class _DayNightGuideSheet extends StatelessWidget {
  const _DayNightGuideSheet({required this.pair});

  final DayNightPair pair;

  Future<void> _openShortcuts(BuildContext context) async {
    PrismHaptics.selection();
    final String message = context.l10n.wallpaperShortcutsOpenError;
    bool opened = false;
    try {
      opened = await launchUrl(Uri.parse('shortcuts://'), mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      logger.w('Could not open Shortcuts', error: error, stackTrace: stackTrace);
    }
    if (!opened) toasts.error(message);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String dayTime = dayNightTimeLabel(context, pair.times.dayStart);
    final String nightTime = dayNightTimeLabel(context, pair.times.nightStart);
    final String screens = switch (pair.target) {
      WallpaperTarget.home => l10n.dayNightGuideScreensHome,
      WallpaperTarget.lock => l10n.dayNightGuideScreensLock,
      WallpaperTarget.both => l10n.dayNightGuideScreensBoth,
    };
    final List<String> steps = <String>[
      l10n.dayNightGuideStepAutomation,
      l10n.dayNightGuideStepTime(dayTime),
      l10n.dayNightGuideStepRun,
      l10n.dayNightGuideStepBlank,
      l10n.dayNightGuideStepGet,
      l10n.dayNightGuideStepSet(screens),
      l10n.dayNightGuideStepRepeat(nightTime),
    ];

    return PrismSheetBody(
      title: l10n.dayNightGuideTitle,
      actions: <Widget>[
        PrismButton(
          label: l10n.wallpaperShortcutsOpenAction,
          icon: Icons.open_in_new_rounded,
          expand: true,
          onPressed: () => _openShortcuts(context),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.dayNightGuideBody(dayTime, nightTime), style: PrismTextStyles.body(context)),
          const SizedBox(height: PrismSpace.md),
          for (final (int index, String step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: PrismSpace.sm),
              child: _GuideStep(number: index + 1, text: step),
            ),
          PrismSectionHeader(title: l10n.dayNightGuideSunTitle, small: true),
          Text(l10n.dayNightGuideSunBody, style: PrismTextStyles.body(context)),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$number. $text',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withValues(alpha: 0.14),
              child: Text(
                '$number',
                style: PrismTextStyles.caption(context).copyWith(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: PrismSpace.sm),
            Expanded(
              child: Text(text, style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}
