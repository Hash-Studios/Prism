import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prism/model/setup/setup_model.dart';
import 'package:prism/model/wallhaven/wallhaven_search_state.dart';
import 'package:prism/services/logger.dart';
import 'package:rxdart/rxdart.dart';

class SetupService {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final _setupSearchSubject = BehaviorSubject<List<Setup>>();
  final _searchStateSubject =
      BehaviorSubject<SearchState>.seeded(SearchState.ready);
  ValueStream<List<Setup>> get setupSearchStream => _setupSearchSubject.stream;
  List<Setup> get setupSearch => _setupSearchSubject.stream.value;
  ValueStream<SearchState> get searchStateStream => _searchStateSubject.stream;

  void dispose() {
    _setupSearchSubject.close();
    _searchStateSubject.close();
  }

  Future<void> clearSearchResults() async {
    _searchStateSubject.add(SearchState.busy);
    _setupSearchSubject.add([]);
    _searchStateSubject.add(SearchState.ready);
  }

  Future<void> getSearchResults() async {
    _searchStateSubject.add(SearchState.busy);
    // await _firebaseFirestore.collection("setupsV3").snapshots().listen((snapshot) {
    //   final setups = snapshot.docs.map((doc) => Setup.fromJson(doc.data())).toList();
    //   _setupSearchSubject.add(setups);
    //   _searchStateSubject.add(SearchState.ready);
    // }).onError((error) {
    //   _searchStateSubject.add(SearchState.error);
    // });
    await _firebaseFirestore.collection("setupsv3").get().then((snapshot) {
      final setups =
          snapshot.docs.map((doc) => Setup.fromJson(doc.data())).toList();
      logger.d(setups);
      _setupSearchSubject.add(setups);
      _searchStateSubject.add(SearchState.ready);
    }).catchError((error) {
      _searchStateSubject.add(SearchState.error);
    });
  }
}
