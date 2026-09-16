import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/source_feed_grid.dart';
import 'package:flutter/material.dart';

class WallHavenGrid extends StatelessWidget {
  const WallHavenGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return const SourceFeedGrid<WallhavenFeedItem>(
      surface: AnalyticsSurfaceValue.homeWallhavenGrid,
      listName: ScrollListNameValue.wallhavenGrid,
      sourceContextPrefix: 'home_wallhaven_grid',
    );
  }
}
