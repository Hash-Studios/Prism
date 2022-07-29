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

  bool showGeneralCategory = true;
  bool showAnimeCategory = true;
  bool showPeopleCategory = true;

  bool showSFWPurity = true;
  bool showSketchyPurity = false;

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

  void updateCategory() {
    String _categories = Categories.all.toIntString();
    if (!showGeneralCategory) _categories = '0${_categories.substring(1)}';
    if (!showAnimeCategory) _categories = '${_categories[0]}0${_categories[2]}';
    if (!showPeopleCategory) _categories = '${_categories.substring(0, 2)}0';
    if (_categories == '000') {
      _categories = '100';
      showGeneralCategory = true;
    }
    categories = fromIntStringC(_categories);
  }

  void updatePurity() {
    String _purity = Purity.all.toIntString();
    if (!showSFWPurity) _purity = '0${_purity.substring(1)}';
    if (!showSketchyPurity) _purity = '${_purity[0]}0${_purity[2]}';
    if (_purity == '000') {
      _purity = '100';
      showSFWPurity = true;
    }
    purity = fromIntStringP(_purity);
  }

  void toggleOrder() {
    if (order == Order.desc) {
      order = Order.asc;
    } else {
      order = Order.desc;
    }
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
