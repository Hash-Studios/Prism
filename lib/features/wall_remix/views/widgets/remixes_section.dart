import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_remix/biz/remixes_cubit.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The approved remixes of [original] by other creators, as a row of tiles that opens the detail screen and swipes
/// through them. It shows nothing while it loads, when there are none the viewer may open, or when the lookup fails.
class RemixesSection extends StatefulWidget {
  const RemixesSection({required this.original, this.viewer, this.cubit, super.key});

  final PrismWallpaper original;
  final WallViewer? viewer;
  final RemixesCubit? cubit;

  @override
  State<RemixesSection> createState() => _RemixesSectionState();
}

class _RemixesSectionState extends State<RemixesSection> {
  static const double _tileWidth = 96;
  static const double _tileHeight = 160;

  late final RemixesCubit _cubit;
  late final bool _ownsCubit;
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? getIt<RemixesCubit>();
    _load();
  }

  @override
  void didUpdateWidget(covariant RemixesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.original, widget.original) || !_sameViewer(oldWidget.viewer, widget.viewer)) {
      _tracked = false;
      _load();
    }
  }

  void _load() => unawaited(_cubit.load(widget.original, viewer: widget.viewer));

  @override
  void dispose() {
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  void _open(BuildContext context, List<PrismWallpaper> visible, int index) {
    final PrismWallpaper wall = visible[index];
    context.router.push(
      WallpaperDetailRoute(
        entity: FeedItemEntity.prism(id: wall.id, wallpaper: wall),
        heroTag: prismHeroTag(this, index, wall.id),
        feed: WallpaperFeed(
          grid: context,
          tiles: [
            for (final (int i, PrismWallpaper item) in visible.indexed)
              (
                item: FeedItemEntity.prism(id: item.id, wallpaper: item),
                index: i,
                heroTag: prismHeroTag(this, i, item.id),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RemixesCubit, RemixesState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state case RemixesLoaded(:final remixes) when !_tracked) {
          _tracked = true;
          analytics.track(RemixesGridOpenedEvent(count: remixes.length));
        }
      },
      builder: (context, state) {
        switch (state) {
          case RemixesLoaded(:final remixes, :final total):
            return _section(context, remixes, total);
          case RemixesLoading():
          case RemixesEmpty():
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _section(BuildContext context, List<PrismWallpaper> visible, int total) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Semantics(header: true, child: Text(l10n.wallRemixesTitle, style: PrismTextStyles.rowTitle(context))),
            const SizedBox(width: 8),
            Text(
              l10n.wallRemixesCount(total),
              style: PrismTextStyles.caption(context).copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _tileHeight + 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final PrismWallpaper wall = visible[index];
              final String creator = _nonBlank(wall.core.authorName) ?? l10n.wallRemixUnknownCreator;
              final String label = l10n.wallRemixOpenRemixLabel(creator);
              return Semantics(
                button: true,
                label: label,
                onTap: () => _open(context, visible, index),
                excludeSemantics: true,
                child: Tooltip(
                  message: label,
                  child: PressScale(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _open(context, visible, index),
                      child: SizedBox(
                        width: _tileWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: _tileWidth,
                              height: _tileHeight,
                              child: PrismImageTile(
                                url: wall.thumbnailUrl,
                                heroTag: prismHeroTag(this, index, wall.id),
                                borderRadius: BorderRadius.circular(PrismRadius.sm),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              creator,
                              style: PrismTextStyles.caption(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

String? _nonBlank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();

bool _sameViewer(WallViewer? first, WallViewer? second) =>
    identical(first, second) ||
    (first != null &&
        second != null &&
        first.isPremium == second.isPremium &&
        listEquals(first.premiumCollections, second.premiumCollections) &&
        setEquals(first.blockedCreatorUids, second.blockedCreatorUids));
