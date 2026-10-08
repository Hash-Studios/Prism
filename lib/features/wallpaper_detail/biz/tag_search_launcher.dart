import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

/// A tag waiting to be searched. The Search screen reads it, runs the query, then sets it back to null.
final ValueNotifier<String?> pendingTagSearch = ValueNotifier<String?>(null);

/// Opens the Search tab for [tag].
void openTagSearch(BuildContext context, String tag) {
  final String query = tag.trim();
  if (query.isEmpty) return;
  pendingTagSearch.value = null;
  pendingTagSearch.value = query;
  context.router.root.navigate(const DashboardRoute(children: <PageRouteInfo>[SearchTabRoute()]));
}
