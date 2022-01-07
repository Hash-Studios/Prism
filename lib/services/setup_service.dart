import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prism/model/setup/setup_model.dart';
import 'package:prism/model/wallhaven/wallhaven_search_state.dart';
import 'package:prism/services/logger.dart';
import 'package:rxdart/rxdart.dart';

class SetupService {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final _setupSearchSubject = BehaviorSubject<List<Setup>>();
  final _setupDocSubject = BehaviorSubject<List<DocumentSnapshot>>();
  final _searchStateSubject =
      BehaviorSubject<SearchState>.seeded(SearchState.ready);
  ValueStream<List<Setup>> get setupSearchStream => _setupSearchSubject.stream;
  List<Setup> get setupSearch => _setupSearchSubject.stream.value;
  ValueStream<SearchState> get searchStateStream => _searchStateSubject.stream;

  void dispose() {
    _setupSearchSubject.close();
    _setupDocSubject.close();
    _searchStateSubject.close();
  }

  Future<void> clearSearchResults() async {
    _searchStateSubject.add(SearchState.busy);
    _setupDocSubject.add([]);
    _setupSearchSubject.add([]);
    _searchStateSubject.add(SearchState.ready);
  }

  Future<void> getSearchResults() async {
    _searchStateSubject.add(SearchState.busy);
    await _firebaseFirestore
        .collection("setupsv3")
        .where("review", isEqualTo: true)
        .orderBy("created_at", descending: true)
        .limit(10)
        .get()
        .then((snapshot) {
      _setupDocSubject.add(snapshot.docs);
      final setups =
          snapshot.docs.map((doc) => Setup.fromJson(doc.data())).toList();
      logger.d(setups);
      _setupSearchSubject.add(setups);
      _searchStateSubject.add(SearchState.ready);
    }).catchError((error) {
      _searchStateSubject.add(SearchState.error);
    });
  }

  Future<void> getMoreSearchResults() async {
    _searchStateSubject.add(SearchState.busy);
    await _firebaseFirestore
        .collection("setupsv3")
        .where("review", isEqualTo: true)
        .orderBy("created_at", descending: true)
        .startAfterDocument(
            _setupDocSubject.value[_setupDocSubject.value.length - 1])
        .limit(10)
        .get()
        .then((snapshot) {
      _setupDocSubject.add(snapshot.docs);
      final setups =
          snapshot.docs.map((doc) => Setup.fromJson(doc.data())).toList();
      logger.d(setups);
      _setupSearchSubject.add(setups);
      _searchStateSubject.add(SearchState.ready);
    }).catchError((error) {
      _searchStateSubject.add(SearchState.error);
    });
  }

  Future<Setup?> getSetupFromName(String name) async {
    _searchStateSubject.add(SearchState.busy);
    await _firebaseFirestore
        .collection("setupsv3")
        .where("name", isEqualTo: name)
        .get()
        .then((snapshot) {
      final setups =
          snapshot.docs.map((doc) => Setup.fromJson(doc.data())).toList();
      logger.d(setups);
      _searchStateSubject.add(SearchState.ready);
      return setups.isNotEmpty ? setups.first : null;
    }).catchError((error) {
      _searchStateSubject.add(SearchState.error);
      return null;
    });
  }
}
