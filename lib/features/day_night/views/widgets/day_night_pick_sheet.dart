import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/views/pages/day_night_screen.dart';
import 'package:Prism/features/day_night/domain/day_night_variants.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the sheet that sets [item] as the day wall, the night wall, or the light and dark pair of its variants.
Future<void> showDayNightPickSheet(BuildContext context, {required FeedItemEntity item, VariantGroup? variants}) {
  final DayNightBloc bloc = context.read<DayNightBloc>();
  final AppLocalizations l10n = context.l10n;
  final DayNightWall wall = DayNightWall.fromFeedItem(item);
  final ({DayNightWall day, DayNightWall night})? pair = variants == null ? null : dayNightFromVariants(variants);
  final DayNightPair current = bloc.state.pair;

  return showPrismSheet<void>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    builder: (sheetContext) {
      void choose(DayNightEvent event, String message) {
        bloc.add(event);
        Navigator.of(sheetContext).pop();
        toasts.success(
          message,
          action: (
            label: l10n.dayNightOpenAction,
            onPressed: () {
              if (context.mounted) unawaited(openDayNightScreen(context));
            },
          ),
        );
      }

      return PrismSheetBody(
        title: l10n.dayNightTitle,
        child: PrismGroup(
          children: <Widget>[
            _DayNightRow(
              icon: Icons.light_mode_rounded,
              title: l10n.dayNightUseAsDay,
              current: current.day,
              onTap: () => choose(DayNightEvent.wallPicked(DayNightSlot.day, wall), l10n.dayNightDaySetToast),
            ),
            _DayNightRow(
              icon: Icons.dark_mode_rounded,
              title: l10n.dayNightUseAsNight,
              current: current.night,
              onTap: () => choose(DayNightEvent.wallPicked(DayNightSlot.night, wall), l10n.dayNightNightSetToast),
            ),
            if (pair != null)
              _DayNightRow(
                icon: Icons.contrast_rounded,
                title: l10n.dayNightUseVariants,
                onTap: () =>
                    choose(DayNightEvent.variantsPicked(day: pair.day, night: pair.night), l10n.dayNightPairSetToast),
              ),
          ],
        ),
      );
    },
  );
}

class _DayNightRow extends StatelessWidget {
  const _DayNightRow({required this.icon, required this.title, required this.onTap, this.current});

  final IconData icon;
  final String title;
  final DayNightWall? current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DayNightWall? wall = current;
    return PrismRow(
      icon: icon,
      title: title,
      onTap: onTap,
      trailing: wall == null
          ? null
          : ExcludeSemantics(
              child: SizedBox.square(
                dimension: 32,
                child: PrismImageTile(
                  url: wall.thumbnailUrl,
                  fallbackUrl: wall.source == WallpaperSource.prism ? null : wall.fullUrl,
                  borderRadius: const BorderRadius.all(Radius.circular(PrismRadius.xs)),
                ),
              ),
            ),
    );
  }
}
