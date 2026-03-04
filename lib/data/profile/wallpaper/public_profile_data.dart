import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;

Stream<List<Map<String, dynamic>>> getUserProfile(String identifier) {
  final String value = identifier.trim();
  final bool isEmail = value.contains('@');
  final String v2Field = isEmail ? 'email' : 'username';

  return firestoreClient
      .watchQuery<Map<String, dynamic>>(
        FirestoreQuerySpec(
          collection: USER_NEW_COLLECTION,
          sourceTag: 'profile.stream.v2',
          filters: <FirestoreFilter>[FirestoreFilter(field: v2Field, op: FirestoreFilterOp.isEqualTo, value: value)],
          limit: 1,
          isStream: true,
        ),
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
      )
      .asyncMap((event) async {
        if (event.isNotEmpty) {
          return event;
        }
        if (!isEmail) {
          final byEmailFallback = await firestoreClient.query<Map<String, dynamic>>(
            FirestoreQuerySpec(
              collection: USER_NEW_COLLECTION,
              sourceTag: 'profile.stream.v2_email_fallback',
              filters: <FirestoreFilter>[
                FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: value),
              ],
              limit: 1,
            ),
            (data, docId) => <String, dynamic>{...data, '__docId': docId},
          );
          if (byEmailFallback.isNotEmpty) {
            return byEmailFallback;
          }
        }
        return firestoreClient.query<Map<String, dynamic>>(
          FirestoreQuerySpec(
            collection: USER_OLD_COLLECTION,
            sourceTag: 'profile.stream.legacy_fallback',
            filters: <FirestoreFilter>[FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: value)],
            limit: 1,
          ),
          (data, docId) => <String, dynamic>{...data, '__docId': docId},
        );
      });
}

Future<void> follow(String email, String id) async {
  await firestoreClient.updateDoc(USER_NEW_COLLECTION, app_state.prismUser.id, {
    'following': FirestoreSentinels.arrayUnion(<Object?>[email]),
  }, sourceTag: 'profile.follow.current_user');
  await firestoreClient.updateDoc(USER_NEW_COLLECTION, id, {
    'followers': FirestoreSentinels.arrayUnion(<Object?>[app_state.prismUser.email]),
  }, sourceTag: 'profile.follow.target_user');
}

Future<void> unfollow(String email, String id) async {
  await firestoreClient.updateDoc(USER_NEW_COLLECTION, app_state.prismUser.id, {
    'following': FirestoreSentinels.arrayRemove(<Object?>[email]),
  }, sourceTag: 'profile.unfollow.current_user');
  await firestoreClient.updateDoc(USER_NEW_COLLECTION, id, {
    'followers': FirestoreSentinels.arrayRemove(<Object?>[app_state.prismUser.email]),
  }, sourceTag: 'profile.unfollow.target_user');
}
