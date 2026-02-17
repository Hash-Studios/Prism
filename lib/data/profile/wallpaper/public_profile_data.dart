import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/data/links/model/linksModel.dart';
import 'package:Prism/global/globals.dart' as globals;

Stream<List<Map<String, dynamic>>> getUserProfile(String email) {
  return firestoreClient
      .watchQuery<Map<String, dynamic>>(
    FirestoreQuerySpec(
      collection: USER_NEW_COLLECTION,
      sourceTag: 'profile.stream.v2',
      filters: <FirestoreFilter>[
        FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
      ],
      limit: 1,
      isStream: true,
    ),
    (data, docId) => <String, dynamic>{...data, '__docId': docId},
  )
      .asyncMap((event) async {
    if (event.isNotEmpty) {
      return event;
    }
    return firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: USER_OLD_COLLECTION,
        sourceTag: 'profile.stream.legacy_fallback',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
        ],
        limit: 1,
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
  });
}

Future<void> follow(String email, String id) async {
  await firestoreClient.updateDoc(
      USER_NEW_COLLECTION,
      globals.prismUser.id,
      {
        'following': FirestoreSentinels.arrayUnion(<Object?>[email]),
      },
      sourceTag: 'profile.follow.current_user');
  await firestoreClient.updateDoc(
      USER_NEW_COLLECTION,
      id,
      {
        'followers': FirestoreSentinels.arrayUnion(<Object?>[globals.prismUser.email]),
      },
      sourceTag: 'profile.follow.target_user');
}

Future<void> unfollow(String email, String id) async {
  await firestoreClient.updateDoc(
      USER_NEW_COLLECTION,
      globals.prismUser.id,
      {
        'following': FirestoreSentinels.arrayRemove(<Object?>[email]),
      },
      sourceTag: 'profile.unfollow.current_user');
  await firestoreClient.updateDoc(
      USER_NEW_COLLECTION,
      id,
      {
        'followers': FirestoreSentinels.arrayRemove(<Object?>[globals.prismUser.email]),
      },
      sourceTag: 'profile.unfollow.target_user');
}

Future<void> setUserLinks(List<LinksModel> linklist, String id) async {
  final Map<String, dynamic> updateLink = <String, dynamic>{};
  for (final element in linklist) {
    updateLink[element.name] = element.link;
  }
  await firestoreClient.updateDoc(
    FirebaseCollections.usersV2,
    id,
    <String, dynamic>{'links': updateLink},
    sourceTag: 'profile.update_links',
  );
}
