import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism/prism_bits.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WallOfTheDayCard extends StatefulWidget {
  const WallOfTheDayCard({super.key});

  @override
  State<WallOfTheDayCard> createState() => _WallOfTheDayCardState();
}

class _WallOfTheDayCardState extends State<WallOfTheDayCard> {
  // The home carousel rebuilds this card on every loop, so count one view per wall per app session.
  static final Set<String> _viewedWallIds = <String>{};

  void _fireImpression(WallOfTheDayEntity entity) {
    if (!_viewedWallIds.add(entity.wallId)) return;
    unawaited(analytics.track(WotdViewedEvent(wallId: entity.wallId)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WotdBloc, WotdState>(
      builder: (context, state) {
        final entity = state.entity;
        if (entity == null) return const SizedBox.shrink();
        _fireImpression(entity);
        return _WotdCardContent(entity: entity);
      },
    );
  }
}

class _WotdCardContent extends StatelessWidget {
  const _WotdCardContent({required this.entity});

  final WallOfTheDayEntity entity;

  FeedItemEntity? get _quickActionItem {
    final PrismWallpaper? wallpaper = entity.wallpaper;
    if (wallpaper != null) return PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper);
    if (entity.url.isEmpty || entity.wallId.isEmpty) return null;
    final WallpaperSource source = entity.source == WallpaperSource.unknown ? WallpaperSource.prism : entity.source;
    final WallpaperCore core = WallpaperCore(
      id: entity.wallId,
      source: source,
      fullUrl: entity.url,
      thumbnailUrl: entity.thumbnailUrl,
      authorName: entity.photographer,
    );
    return switch (source) {
      WallpaperSource.prism => PrismFeedItem(
        id: core.id,
        wallpaper: PrismWallpaper(core: core, firestoreDocumentId: entity.wallDocumentId),
      ),
      WallpaperSource.wallhaven => WallhavenFeedItem(
        id: core.id,
        wallpaper: WallhavenWallpaper(core: core),
      ),
      WallpaperSource.pexels => PexelsFeedItem(
        id: core.id,
        wallpaper: PexelsWallpaper(core: core),
      ),
      _ => null,
    };
  }

  void _openWallpaper(BuildContext context) {
    unawaited(analytics.track(WotdOpenedEvent(wallId: entity.wallId, source: 'card_tap')));
    CoinsService.instance.reportQuestEvent(QuestEvent.viewWotd);
    final PrismWallpaper? wallpaper = entity.wallpaper;
    context.router.push(
      wallpaper != null
          ? WallpaperDetailRoute(
              entity: PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper),
            )
          : WallpaperDetailRoute(
              wallId: entity.wallId,
              source: entity.source == WallpaperSource.unknown ? WallpaperSource.prism : entity.source,
              thumbnailUrl: entity.thumbnailUrl.isNotEmpty ? entity.thumbnailUrl : entity.url,
            ),
    );
  }

  void _openArchive(BuildContext context) {
    PrismHaptics.tap();
    context.router.push(const WotdArchiveRoute());
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String photographer = entity.photographer.trim();
    final Widget card = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FeedHeroCard(
          image: PrismImageTile(
            url: entity.thumbnailUrl,
            fallbackUrl: entity.url,
            memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
          ),
          semanticLabel: photographer.isEmpty
              ? context.l10n.wallpaperWotdTitle
              : context.l10n.wallpaperWotdByPhotographer(photographer),
          title: photographer.isEmpty ? null : context.l10n.wallpaperWotdByline(photographer),
          textEndInset: _pillEnd + _pillWidth(context) - PrismSpace.md + PrismSpace.sm,
          tag: ClipRRect(
            borderRadius: BorderRadius.circular(PrismRadius.pill),
            child: ColoredBox(
              color: cs.surfaceContainerHigh,
              child: PrismTag(label: context.l10n.wallpaperWotdTitle),
            ),
          ),
          onTap: () {
            PrismHaptics.tap();
            _openWallpaper(context);
          },
        ),
        // A sibling of the card, not a child, so the card's own semantics do not swallow it.
        // Bottom right, as on the current app: the target is 16 from the end edge. Its bottom is 26 up, which keeps the
        // centre of the image retry button (24 from the corner) out of reach of the pill.
        PositionedDirectional(
          bottom: _pillBottom,
          end: _pillEnd,
          child: _PastPicksPill(onTap: () => _openArchive(context)),
        ),
      ],
    );
    final FeedItemEntity? item = _quickActionItem;
    return item == null ? card : WallpaperQuickActionRegion(item: item, child: card);
  }
}

const double _pillEnd = 16;

/// The label of the pill. The pill grows with it up to 1.5x text.
TextStyle _pillLabelStyle(BuildContext context) =>
    PrismTextStyles.caption(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: PrismColors.onPrimary);

/// The width of the pill: 14 and 8 of padding, a 2 gap, an 18 chevron and the label.
double _pillWidth(BuildContext context) {
  final TextPainter label = TextPainter(
    text: TextSpan(text: context.l10n.wallpaperWotdPastPicks, style: _pillLabelStyle(context)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
    maxLines: 1,
  )..layout();
  final double width = 14 + label.width + 2 + 18 + 8;
  label.dispose();
  return width;
}

const double _pillBottom = 26;

/// Opens the archive of earlier picks. A 36 point glass pill on the image inside a 48 point tap target. Its look is the
/// current app's: liquid glass over a scrim tint, with the label and chevron in the on-primary white.
class _PastPicksPill extends StatelessWidget {
  const _PastPicksPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: context.l10n.wallpaperWotdSeePast,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PressScale(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.5,
                child: PrismGlass(
                  borderRadius: 18,
                  thickness: 16,
                  glassColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
                  child: SizedBox(
                    key: const ValueKey<String>('wotd-past-picks-pill'),
                    height: 36,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(context.l10n.wallpaperWotdPastPicks, maxLines: 1, style: _pillLabelStyle(context)),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: PrismColors.onPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
