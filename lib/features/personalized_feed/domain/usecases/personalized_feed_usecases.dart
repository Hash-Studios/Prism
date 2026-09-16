import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FetchPersonalizedFeedUseCase implements UseCase<PersonalizedFeedPage, FetchPersonalizedFeedRequest> {
  FetchPersonalizedFeedUseCase(this._repository);

  final PersonalizedFeedRepository _repository;

  @override
  Future<Result<PersonalizedFeedPage>> call(FetchPersonalizedFeedRequest request) {
    return _repository.fetch(request);
  }
}
