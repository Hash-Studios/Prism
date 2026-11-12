import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

/// A search that another screen or a link asked for. [filters] replace the filters on screen; null keeps them.
typedef SearchRequest = ({String query, SearchFilters? filters});

/// A search waiting to run. The Search screen reads it, runs it, then sets it back to null.
final ValueNotifier<SearchRequest?> pendingSearch = ValueNotifier<SearchRequest?>(null);

/// Opens the Search tab for [tag].
void openTagSearch(BuildContext context, String tag) {
  final String query = tag.trim();
  if (query.isEmpty) return;
  pendingSearch.value = null;
  pendingSearch.value = (query: query, filters: null);
  context.router.root.navigate(const DashboardRoute(children: <PageRouteInfo>[SearchTabRoute()]));
}
