import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:injectable/injectable.dart';

class FetchPersonalizedFeedParams {
  const FetchPersonalizedFeedParams({
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

@lazySingleton
class FetchPersonalizedFeedUseCase implements UseCase<PersonalizedFeedPage, FetchPersonalizedFeedParams> {
  FetchPersonalizedFeedUseCase(this._repository);

  final PersonalizedFeedRepository _repository;

  @override
  Future<Result<PersonalizedFeedPage>> call(FetchPersonalizedFeedParams params) {
    return _repository.fetch(
      FetchPersonalizedFeedRequest(
        page: params.page,
        refresh: params.refresh,
        seenKeys: params.seenKeys,
        existingItems: params.existingItems,
      ),
    );
  }
}
