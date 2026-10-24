import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';

/// Canonical usernames are published only by the server's reservation transaction.
class UsernameService {
  UsernameService({Future<Object?> Function(Map<String, Object?> data)? request}) : _request = request ?? _call;

  static UsernameService instance = UsernameService();
  final Future<Object?> Function(Map<String, Object?> data) _request;

  Future<String> claim(String username, {bool initial = false}) async {
    final Object? response = await _request(<String, Object?>{'username': username, if (initial) 'initial': true});
    if (response is! Map) throw StateError('Invalid username response.');
    final Object? claimed = response['username'];
    if (claimed is! String || !RegExp(r'^\w{3,30}$').hasMatch(claimed)) {
      throw StateError('Invalid canonical username.');
    }
    return claimed;
  }

  /// A hint for editing only. The callable rechecks ownership atomically at save time.
  Future<bool> isAvailable(String username, String uid) async {
    final String? owner = await firestoreClient.getById<String>(
      'usernames',
      username.toLowerCase(),
      (data, _) => data['uid'] is String ? data['uid'] as String : '',
      sourceTag: 'profile.edit.usernameReservation',
    );
    return owner == null || owner == uid;
  }

  static Future<Object?> _call(Map<String, Object?> data) async =>
      (await appFunctions.httpsCallable('claimUsername').call<Object?>(data)).data;
}
