import 'package:flutter/cupertino.dart';
import 'package:prism/model/wallhaven/wallhaven_categories.dart';
import 'package:prism/model/wallhaven/wallhaven_order.dart';
import 'package:prism/model/wallhaven/wallhaven_purity.dart';
import 'package:prism/model/wallhaven/wallhaven_search_state.dart';
import 'package:prism/model/wallhaven/wallhaven_sorting.dart';
import 'package:prism/model/wallhaven/wallhaven_wall_model.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/logger.dart';
import 'package:prism/services/wallhaven_service.dart';

class WallHavenController with ChangeNotifier {
  final WallHavenService _wallHavenService = locator<WallHavenService>();

  Stream<List<WallHavenWall>> get wallSearchStream =>
      _wallHavenService.wallSearchStream;
  Stream<SearchState> get searchStateStream =>
      _wallHavenService.searchStateStream;

  Categories get categories => _wallHavenService.categories;
  Purity get purity => _wallHavenService.purity;
  int get page => _wallHavenService.page;
  Order get order => _wallHavenService.order;
  Sorting get sorting => _wallHavenService.sorting;
  String? get query => _wallHavenService.query;

  set categories(Categories categories) {
    _wallHavenService.categories = categories;
    logger.i("categories: ${categories.toIntString()}");
    notifyListeners();
  }

  set purity(Purity purity) {
    _wallHavenService.purity = purity;
    logger.i("purty: ${purity.toIntString()}");
    notifyListeners();
  }

  set page(int page) {
    _wallHavenService.page = page;
    logger.i("page: $page");
    notifyListeners();
  }

  set order(Order order) {
    _wallHavenService.order = order;
    logger.i("order: ${order.toShortString()}");
    notifyListeners();
  }

  set sorting(Sorting sorting) {
    _wallHavenService.sorting = sorting;
    logger.i("sorting: ${sorting.toShortString()}");
    notifyListeners();
  }

  set query(String? query) {
    _wallHavenService.query = query;
    logger.i("query: $query");
    notifyListeners();
  }

  Future<void> getSearchResults() async {
    await _wallHavenService.getSearchResults();
    notifyListeners();
  }

  Future<void> clearSearchResults() async {
    await _wallHavenService.clearSearchResults();
    notifyListeners();
  }

  Future<void> clearSearchFilters() async {
    await _wallHavenService.clearSearchFilters();
    notifyListeners();
  }

  Future<void> clearSearchSorting() async {
    await _wallHavenService.clearSearchSorting();
    notifyListeners();
  }
}
