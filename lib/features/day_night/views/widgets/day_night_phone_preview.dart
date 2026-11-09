import 'dart:async';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/readability/views/readability_views.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The time of [time] as the device shows it, for example 7:00 AM or 19:00.
String dayNightTimeLabel(BuildContext context, DayTime time) => MaterialLocalizations.of(context).formatTimeOfDay(
  TimeOfDay(hour: time.hour, minute: time.minute),
  alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
);

/// One phone-shaped preview of the day or night wall, with its clock, label and start time under it.
class DayNightPhonePreview extends StatelessWidget {
  const DayNightPhonePreview({
    super.key,
    required this.slot,
    required this.wall,
    required this.time,
    this.needsDownload = false,
  });

  final DayNightSlot slot;
  final DayNightWall? wall;

  /// The start time of [slot], as the device formats it.
  final String time;

  /// True when the wall is a protected Prism original that is not downloaded yet.
  final bool needsDownload;

  /// The phone is a picture of the lock screen, so it keeps one size and its clock ignores text scaling.
  static const double phoneHeight = 236;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isDay = slot == DayNightSlot.day;
    final String slotLabel = isDay ? l10n.dayNightDayLabel : l10n.dayNightNightLabel;
    final DayNightWall? current = wall;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.md);

    final Widget screen = AnimatedSwitcher(
      duration: context.motion(PrismDurations.fast),
      child: current == null
          ? _EmptyScreen(key: const ValueKey<String>('empty'), time: time, isDay: isDay)
          : _WallScreen(key: ValueKey<String>(current.id), wall: current, time: time),
    );

    return Column(
      children: <Widget>[
        Semantics(
          container: true,
          label: l10n.dayNightPreviewLabel(slotLabel, time),
          child: ExcludeSemantics(
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: phoneHeight,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 19.5,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: ClipRRect(
                          borderRadius: radius,
                          child: MediaQuery.withNoTextScaling(child: screen),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PrismSpace.sm),
                Text(slotLabel, textAlign: TextAlign.center, style: PrismTextStyles.rowTitle(context)),
                const SizedBox(height: PrismSpace.xxs),
                Text(
                  current == null ? (isDay ? l10n.dayNightEmptyDay : l10n.dayNightEmptyNight) : l10n.dayNightFrom(time),
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.caption(context),
                ),
              ],
            ),
          ),
        ),
        if (needsDownload && current != null) ...<Widget>[
          const SizedBox(height: PrismSpace.xs),
          Text(
            l10n.dayNightNeedsDownload,
            textAlign: TextAlign.center,
            style: PrismTextStyles.caption(context).copyWith(color: cs.error),
          ),
          const SizedBox(height: PrismSpace.xs),
          PrismButton(
            label: l10n.dayNightOpenWall,
            variant: PrismButtonVariant.tonal,
            size: PrismButtonSize.compact,
            onPressed: () => unawaited(
              context.router.push(
                WallpaperDetailRoute(wallId: current.id, source: current.source, thumbnailUrl: current.thumbnailUrl),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WallScreen extends StatelessWidget {
  const _WallScreen({super.key, required this.wall, required this.time});

  final DayNightWall wall;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (wall.fixes.isEmpty)
          PrismImageTile(url: wall.thumbnailUrl, borderRadius: BorderRadius.circular(PrismRadius.md))
        else
          ReadabilityFixedImage(
            key: const ValueKey<String>('day-night-fixed-wall'),
            provider: CachedNetworkImageProvider(wall.thumbnailUrl),
            fixes: wall.fixes,
          ),
        Align(
          alignment: const Alignment(0, -0.8),
          child: _Clock(time: time, color: Colors.white),
        ),
      ],
    );
  }
}

class _EmptyScreen extends StatelessWidget {
  const _EmptyScreen({super.key, required this.time, required this.isDay});

  final String time;
  final bool isDay;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: Icon(
              isDay ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 32,
              color: cs.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.8),
            child: _Clock(time: time, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.time, required this.color});

  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          time,
          textAlign: TextAlign.center,
          style: PrismTextStyles.screenTitle(context).copyWith(
            fontSize: 28,
            height: 1.0,
            fontWeight: FontWeight.w500,
            color: color,
            shadows: <Shadow>[Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12)],
          ),
        ),
      ),
    );
  }
}
