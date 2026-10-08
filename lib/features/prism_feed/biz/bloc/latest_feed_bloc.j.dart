import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:injectable/injectable.dart';

/// The newest reviewed Prism wallpapers, for the Latest chip on the home feed.
@injectable
class LatestFeedBloc extends PagedFeedBloc {
  LatestFeedBloc(this._repository)
    : super(surface: AnalyticsSurfaceValue.homeLatestGrid, sourceContext: 'home_latest_feed');

  final PrismWallpaperRepository _repository;

  @override
  Future<Result<PersonalizedFeedPage>> loadPage(int page) async {
    final result = await _repository.fetchFeed(refresh: page == 1);
    if (result.isFailure) {
      return Result.error(result.failure!);
    }
    return Result.success(
      PersonalizedFeedPage(
        items: (result.data ?? const <PrismWallpaper>[])
            .map((wall) => FeedItemEntity.prism(id: wall.id, wallpaper: wall))
            .toList(growable: false),
        hasMore: _repository.hasMore,
      ),
    );
  }
}
