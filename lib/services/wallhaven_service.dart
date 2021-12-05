import 'package:prism/model/wallhaven/wallhaven_categories.dart';
import 'package:prism/model/wallhaven/wallhaven_order.dart';
import 'package:prism/model/wallhaven/wallhaven_purity.dart';
import 'package:prism/model/wallhaven/wallhaven_search_response_model.dart';
import 'package:prism/model/wallhaven/wallhaven_search_state.dart';
import 'package:prism/model/wallhaven/wallhaven_sorting.dart';
import 'package:prism/model/wallhaven/wallhaven_wall_model.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/wallhaven_api.dart';
import 'package:rxdart/rxdart.dart';

class WallHavenService {
  final WallHavenAPI _wallHavenAPI = locator<WallHavenAPI>();
  final _wallSearchSubject = BehaviorSubject<List<WallHavenWall>>();
  final _searchStateSubject =
      BehaviorSubject<SearchState>.seeded(SearchState.ready);
  ValueStream<List<WallHavenWall>> get wallSearchStream =>
      _wallSearchSubject.stream;
  ValueStream<SearchState> get searchStateStream => _searchStateSubject.stream;

  Categories categories = Categories.all;
  Purity purity = Purity.onlySfw;
  int page = 1;
  Order order = Order.desc;
  Sorting sorting = Sorting.dateAdded;
  String? query;

  void dispose() {
    _wallHavenAPI.dispose();
    _wallSearchSubject.close();
    _searchStateSubject.close();
  }

  Future<void> clearSearchResults() async {
    page = 1;
    _searchStateSubject.add(SearchState.busy);
    _wallSearchSubject.add([]);
    _searchStateSubject.add(SearchState.ready);
  }

  Future<void> clearSearchFilters() async {
    categories = Categories.all;
    purity = Purity.onlySfw;
  }

  Future<void> clearSearchSorting() async {
    sorting = Sorting.dateAdded;
    order = Order.desc;
  }

  Future<void> getSearchResults() async {
    _searchStateSubject.add(SearchState.busy);
    final WallHavenSearchResponse? _wallSearchResponse =
        await _wallHavenAPI.getSearchResults(
      categories: categories.toIntString(),
      order: order.toShortString(),
      page: page,
      purity: purity.toIntString(),
      query: query,
      sorting: sorting.toShortString(),
    );
    if (_wallSearchResponse != null) {
      final List<WallHavenWall> _currentData =
          _wallSearchSubject.valueOrNull ?? [];
      _currentData.addAll(_wallSearchResponse.data);
      _wallSearchSubject.add(_currentData);
      _searchStateSubject.add(SearchState.ready);
    } else {
      _searchStateSubject.add(SearchState.error);
    }
  }
}
