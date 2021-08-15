import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

enum UserDiscoveryState { ready, busy }

class UserService {
  final _sessionsSubject = BehaviorSubject<List<PrismUsersV2>>();
  final _stateSubject =
      BehaviorSubject<UserDiscoveryState>.seeded(UserDiscoveryState.busy);
  final collection = FirebaseFirestore.instance.collection(USER_NEW_COLLECTION);

  ValueStream<List<PrismUsersV2>> get sessionsStream => _sessionsSubject.stream;

  ValueStream<UserDiscoveryState> get userDiscoveryStateStream =>
      _stateSubject.stream;

  Future<void> fetchUsers(String text) async {
    _stateSubject.add(UserDiscoveryState.busy);
    final res = await collection
        .where('name', isGreaterThanOrEqualTo: text)
        .where('name', isLessThanOrEqualTo: text + '\uf8ff')
        .limit(20)
        .get();
    final resUsers = res.docs
        .map((e) => PrismUsersV2.fromDocumentSnapshotWithoutUser(e))
        .toList();
    _stateSubject.add(UserDiscoveryState.ready);

    _sessionsSubject.add(resUsers);
  }

  void dispose() {
    _sessionsSubject.close();
    _stateSubject.close();
  }
}
