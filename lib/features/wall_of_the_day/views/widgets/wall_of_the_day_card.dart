import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wall_of_the_day_shimmer.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const Color _kBrandPink = Color(0xFFE57697);

class WallOfTheDayCard extends StatefulWidget {
  const WallOfTheDayCard({super.key});

  @override
  State<WallOfTheDayCard> createState() => _WallOfTheDayCardState();
}

class _WallOfTheDayCardState extends State<WallOfTheDayCard> {
  bool _impressionFired = false;

  void _fireImpression(WallOfTheDayEntity entity) {
    if (_impressionFired) return;
    _impressionFired = true;
    unawaited(analytics.track(WotdViewedEvent(wallId: entity.wallId)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WotdBloc, WotdState>(
      builder: (context, state) {
        if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
          return const WallOfTheDayShimmer();
        }
        if (state.status == LoadStatus.failure || state.entity == null) {
          return const SizedBox.shrink();
        }
        final entity = state.entity!;
        _fireImpression(entity);
        return _WotdCardContent(entity: entity);
      },
    );
  }
}

class _WotdCardContent extends StatelessWidget {
  const _WotdCardContent({required this.entity});

  final WallOfTheDayEntity entity;

  /// Builds a Prism-shaped map so WallpaperScreen can reuse the Prism branch for WOTD.
  static List<dynamic> _wallpaperRouteArguments(WallOfTheDayEntity entity) {
    final wallMap = <String, dynamic>{
      'id': entity.wallId,
      'desc': entity.title,
      'size': '',
      'email': entity.photographerId.isNotEmpty ? entity.photographerId : '',
      'userPhoto': '',
      'by': entity.photographer,
      'resolution': '',
      'wallpaper_url': entity.url,
      'wallpaper_thumb': entity.thumbnailUrl,
      'collections': <String>[],
    };
    return ['WallOfTheDay', wallMap, entity.thumbnailUrl];
  }

  void _openWallpaper(BuildContext context) {
    unawaited(analytics.track(WotdOpenedEvent(wallId: entity.wallId, source: 'card_tap')));
    context.router.push(WallpaperRoute(arguments: _wallpaperRouteArguments(entity)));
  }

  void _setAsWallpaper(BuildContext context) {
    unawaited(analytics.track(WotdSetAsWallpaperEvent(wallId: entity.wallId)));
    context.router.push(WallpaperRoute(arguments: _wallpaperRouteArguments(entity)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openWallpaper(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              CachedNetworkImage(
                imageUrl: entity.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.white10),
                errorWidget: (_, __, ___) => Container(color: Colors.white10),
              ),

              // Gradient overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.4, 1.0],
                  ),
                ),
              ),

              // Top-left label
              Positioned(
                top: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, color: _kBrandPink, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Wall of the Day',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom content
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Title + photographer
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (entity.title.isNotEmpty)
                            Text(
                              entity.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          if (entity.photographer.isNotEmpty)
                            Text(
                              'by ${entity.photographer}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    if (!hideSetWallpaperUi) ...<Widget>[
                      const SizedBox(width: 8),
                      // Set Wallpaper CTA
                      GestureDetector(
                        onTap: () => _setAsWallpaper(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: _kBrandPink, borderRadius: BorderRadius.circular(20)),
                          child: const Text(
                            'Set Wallpaper',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
