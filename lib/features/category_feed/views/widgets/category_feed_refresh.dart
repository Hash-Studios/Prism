import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';

/// Reloads the selected category and completes when the reload settles, so a pull-to-refresh spinner lasts exactly as
/// long as the load. Returns at once when no category is selected yet.
Future<void> refreshCategoryFeed(CategoryFeedBloc bloc, {Duration timeout = const Duration(seconds: 30)}) async {
  if (bloc.state.selectedCategory == null) {
    return;
  }
  final Future<CategoryFeedState> settled = bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  bloc.add(const CategoryFeedEvent.refreshRequested());
  await settled.timeout(timeout, onTimeout: () => bloc.state);
}
