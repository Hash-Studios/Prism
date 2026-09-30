import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_bits.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
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

  void _openWallpaper(BuildContext context) {
    unawaited(analytics.track(WotdOpenedEvent(wallId: entity.wallId, source: 'card_tap')));
    context.router.push(
      WallpaperDetailRoute(
        wallId: entity.wallId,
        source: entity.source == WallpaperSource.unknown ? WallpaperSource.prism : entity.source,
        thumbnailUrl: entity.thumbnailUrl.isNotEmpty ? entity.thumbnailUrl : entity.url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String photographer = entity.photographer.trim();
    return FeedHeroCard(
      image: PrismImageTile(url: entity.thumbnailUrl, fallbackUrl: entity.url),
      semanticLabel: photographer.isEmpty ? 'Wall of the day' : 'Wall of the day by $photographer',
      title: photographer.isEmpty ? null : 'by $photographer',
      tag: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        child: ColoredBox(
          color: cs.surfaceContainerHigh,
          child: const PrismTag(label: 'Wall of the day'),
        ),
      ),
      onTap: () => _openWallpaper(context),
    );
  }
}
