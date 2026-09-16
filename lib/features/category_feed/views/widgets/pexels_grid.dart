import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/source_feed_grid.dart';
import 'package:flutter/material.dart';

class PexelsGrid extends StatelessWidget {
  const PexelsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return const SourceFeedGrid<PexelsFeedItem>(
      surface: AnalyticsSurfaceValue.homePexelsGrid,
      listName: ScrollListNameValue.pexelsGrid,
      sourceContextPrefix: 'home_pexels_grid',
    );
  }
}
