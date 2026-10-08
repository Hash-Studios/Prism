import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:injectable/injectable.dart';

/// The most viewed wallpapers, for the Popular chip on the home feed.
@injectable
class PopularFeedBloc extends PagedFeedBloc {
  PopularFeedBloc(this._repository)
    : super(surface: AnalyticsSurfaceValue.homePopularGrid, sourceContext: 'home_popular_feed');

  final PersonalizedFeedRepository _repository;

  @override
  Future<Result<PersonalizedFeedPage>> loadPage(int page) => _repository.fetchPopular();
}
