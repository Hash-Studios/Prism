import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';

class FetchPersonalizedFeedRequest {
  const FetchPersonalizedFeedRequest({
    required this.page,
    required this.refresh,
    required this.seenKeys,
    required this.existingItems,
  });

  final int page;
  final bool refresh;
  final List<String> seenKeys;
  final List<FeedItemEntity> existingItems;
}

abstract class PersonalizedFeedRepository {
  Future<Result<PersonalizedFeedPage>> fetch(FetchPersonalizedFeedRequest request);
}
