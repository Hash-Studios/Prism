import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteAccountService {
  DeleteAccountService._();

  static final DeleteAccountService instance = DeleteAccountService._();

  FirestoreClient get _firestore => getIt<FirestoreClient>();
  SettingsLocalDataSource get _settingsLocal => getIt<SettingsLocalDataSource>();

  /// Performs a full account deletion:
  ///   1. Deletes favourite subcollections (usersv2/{id}/images, /setups)
  ///   2. Deletes coinTransactions, aiGenerations, draftSetups owned by this user
  ///   3. Anonymizes the usersv2 doc so uploaded walls/setups still resolve
  ///   4. Deletes the Firebase Auth user record
  ///   5. Clears all local persistence
  Future<void> deleteAccount() async {
    final userId = app_state.prismUser.id;
    final email = app_state.prismUser.email;

    logger.i('[DeleteAccount] Starting deletion for userId=$userId email=$email', tag: 'DeleteAccount');

    if (userId.isEmpty) throw Exception('No signed-in user to delete.');

    // 1. Favourite subcollections
    logger.i('[DeleteAccount] Step 1: Deleting favourite subcollections', tag: 'DeleteAccount');
    await _deleteSubcollection('usersv2/$userId/images');
    await _deleteSubcollection('usersv2/$userId/setups');

    // 2. coinTransactions
    logger.i('[DeleteAccount] Step 2: Deleting coinTransactions', tag: 'DeleteAccount');
    await _deleteBatch(FirebaseCollections.coinTransactions, [
      FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId),
    ], 'delete_account.coin_transactions');

    // 3. aiGenerations
    logger.i('[DeleteAccount] Step 3: Deleting aiGenerations', tag: 'DeleteAccount');
    await _deleteBatch(FirebaseCollections.aiGenerations, [
      FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId),
    ], 'delete_account.ai_generations');

    // 4. draftSetups
    logger.i('[DeleteAccount] Step 4: Deleting draftSetups', tag: 'DeleteAccount');
    await _deleteBatch(FirebaseCollections.draftSetups, [
      FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
    ], 'delete_account.draft_setups');

    // 5. Anonymize usersv2 doc — keeps uploaded walls/setups resolving to "Deleted Account"
    logger.i('[DeleteAccount] Step 5: Anonymizing usersv2 doc', tag: 'DeleteAccount');
    await _firestore.setDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
      'name': 'Deleted Account',
      'profilePhoto': '',
      'bio': '',
      'email': '',
      'following': <String>[],
      'followers': <String>[],
      'premium': false,
      'loggedIn': false,
      'deleted': true,
      'interestCategories': <String>[],
      'onboardingV2': <String, dynamic>{},
      'coinState': <String, dynamic>{},
      'coins': 0,
    }, sourceTag: 'delete_account.anonymize_user');

    // 6. Re-authenticate then delete Firebase Auth user
    logger.i('[DeleteAccount] Step 6: Re-authenticating with Google', tag: 'DeleteAccount');
    await app_state.gAuth.reauthenticateCurrentUser();
    logger.i('[DeleteAccount] Step 6: Deleting Firebase Auth user', tag: 'DeleteAccount');
    await FirebaseAuth.instance.currentUser?.delete();

    // 6b. Sign out from Google SDK so silent re-auth doesn't recreate the account
    logger.i('[DeleteAccount] Step 6b: Signing out from Google SDK', tag: 'DeleteAccount');
    await app_state.gAuth.signOutGoogle();

    // 7. Clear local persistence
    logger.i('[DeleteAccount] Step 7: Clearing local persistence', tag: 'DeleteAccount');
    await _settingsLocal.set(OnboardingV2Keys.onboardedNew, false);
    await _settingsLocal.set(OnboardingV2Keys.selectedInterests, '');
    await _settingsLocal.set(OnboardingV2Keys.followedCreators, '');
    await _settingsLocal.set('session.current_user', '');

    logger.i('[DeleteAccount] Done — account deleted successfully', tag: 'DeleteAccount');
  }

  Future<void> _deleteSubcollection(String collectionPath) async {
    final docIds = await _firestore.query<String>(
      FirestoreQuerySpec(
        collection: collectionPath,
        sourceTag: 'delete_account.list.$collectionPath',
        cachePolicy: FirestoreCachePolicy.networkOnly,
      ),
      (_, docId) => docId,
    );
    logger.d(
      '[DeleteAccount] _deleteSubcollection: $collectionPath — found ${docIds.length} docs',
      tag: 'DeleteAccount',
    );
    for (final docId in docIds) {
      logger.d('[DeleteAccount]   deleting $collectionPath/$docId', tag: 'DeleteAccount');
      await _firestore.deleteDoc(collectionPath, docId, sourceTag: 'delete_account.delete.$collectionPath');
    }
    logger.d('[DeleteAccount] _deleteSubcollection: $collectionPath — done', tag: 'DeleteAccount');
  }

  Future<void> _deleteBatch(String collection, List<FirestoreFilter> filters, String tag) async {
    final docIds = await _firestore.query<String>(
      FirestoreQuerySpec(
        collection: collection,
        sourceTag: tag,
        filters: filters,
        cachePolicy: FirestoreCachePolicy.networkOnly,
      ),
      (_, docId) => docId,
    );
    logger.d('[DeleteAccount] _deleteBatch: $collection — found ${docIds.length} docs', tag: 'DeleteAccount');
    if (docIds.isEmpty) return;
    try {
      await _firestore.runBatch((batch) async {
        for (final docId in docIds) {
          logger.d('[DeleteAccount]   queuing delete $collection/$docId', tag: 'DeleteAccount');
          batch.deleteDoc(collection, docId);
        }
      }, sourceTag: '$tag.batch_delete');
      logger.d('[DeleteAccount] _deleteBatch: $collection — batch committed', tag: 'DeleteAccount');
    } catch (e) {
      // Firestore rules may not allow client-side deletes on this collection.
      // Log and continue — these are non-critical audit records; the important
      // steps (anonymize usersv2 doc + delete Firebase Auth user) still run.
      logger.w(
        '[DeleteAccount] _deleteBatch: $collection — skipped (${e.toString()}). TODO: update Firestore rules to allow user self-delete.',
        tag: 'DeleteAccount',
      );
    }
  }
}
