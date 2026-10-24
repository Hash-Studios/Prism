import 'dart:async';
import 'dart:convert';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: OnboardingV2Repository)
class OnboardingV2RepositoryImpl implements OnboardingV2Repository {
  OnboardingV2RepositoryImpl(
    this._firestoreClient,
    this._settingsLocal, {
    @ignoreParam FirebaseRemoteConfig? remoteConfig,
    @ignoreParam Future<void> Function(String, bool)? setFollow,
  }) : _remoteConfigOverride = remoteConfig,
       _setFollow = setFollow ?? _callSetFollow;

  final FirebaseRemoteConfig? _remoteConfigOverride;
  FirebaseRemoteConfig? get _remoteConfig => _remoteConfigOverride ?? FirebaseInit.remoteConfigIfInitialized;
  final FirestoreClient _firestoreClient;
  final SettingsLocalDataSource _settingsLocal;
  final Future<void> Function(String targetUid, bool following) _setFollow;

  @override
  Future<Result<List<OnboardingStarterCreatorEntity>>> fetchStarterPack() async {
    try {
      final raw = _remoteConfig?.getString(OnboardingV2Config.remoteConfigStarterPackKey) ?? '';
      if (raw.isEmpty) {
        return Result.success(<OnboardingStarterCreatorEntity>[]);
      }
      final decoded = json.decode(raw);
      if (decoded is! List) {
        return Result.success(<OnboardingStarterCreatorEntity>[]);
      }

      // Remote Config carries public profile UIDs + rank; profile data comes from profiles/{uid}.
      final curationEntries = decoded
          .whereType<Map<String, dynamic>>()
          .map(_creatorFromCurationMap)
          .where((e) => e.userId.isNotEmpty)
          .toList(growable: false);

      if (curationEntries.isEmpty) {
        return Result.success(<OnboardingStarterCreatorEntity>[]);
      }

      // Fetch profile + latest wallpapers for every creator in parallel.
      final enriched = await Future.wait(curationEntries.map((entry) => _enrichCreator(entry)));

      return Result.success(enriched.whereType<OnboardingStarterCreatorEntity>().toList(growable: false));
    } catch (error) {
      return Result.error(ServerFailure('Failed to fetch starter pack: $error'));
    }
  }

  /// Fetches live profile data and the last 5 wallpapers for [entry] from Firestore.
  /// Gracefully falls back to the original (empty) entry values on any error.
  Future<OnboardingStarterCreatorEntity?> _enrichCreator(OnboardingStarterCreatorEntity entry) async {
    final (profile, previewUrls) = await (_fetchUserProfile(entry.userId), _fetchPreviewUrls(entry.userId)).wait;
    if (profile == null) return null;

    return OnboardingStarterCreatorEntity(
      userId: profile.userId,
      email: entry.email,
      name: profile.name,
      photoUrl: profile.photoUrl,
      followerCount: profile.followerCount,
      previewUrls: previewUrls,
      rank: entry.rank,
    );
  }

  Future<_CreatorProfile?> _fetchUserProfile(String userId) async {
    try {
      return await _firestoreClient.getById<_CreatorProfile>(FirebaseCollections.profiles, userId, (data, docId) {
        final followerCount = data['followerCount'];
        return _CreatorProfile(
          userId: docId,
          name: data['name']?.toString() ?? '',
          photoUrl: data['profilePhoto']?.toString() ?? '',
          followerCount: followerCount is num ? followerCount.toInt() : 0,
        );
      }, sourceTag: 'onboarding_v2.fetch_creator_profile');
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _fetchPreviewUrls(String userId) async {
    try {
      final rows = await _firestoreClient.query<String>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'onboarding_v2.fetch_creator_walls',
          filters: [
            FirestoreFilter(field: 'creatorUid', op: FirestoreFilterOp.isEqualTo, value: userId),
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
          ],
          orderBy: [const FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: 5,
          cachePolicy: FirestoreCachePolicy.staleWhileRevalidate,
          dedupeWindowMs: 60000,
        ),
        (data, _) {
          final thumb = data['wallpaper_thumb']?.toString() ?? '';
          final url = data['wallpaper_url']?.toString() ?? '';
          return thumb.isNotEmpty || data['originalProtected'] == true ? thumb : url;
        },
      );
      return rows.where((url) => url.isNotEmpty).toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Future<Result<void>> saveInterests({required String userId, required List<String> interests}) async {
    try {
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
        'interestCategories': interests,
        'onboardingV2.selectedInterests': interests,
      }, sourceTag: 'onboarding_v2.save_interests');
      await _settingsLocal.set(OnboardingV2Keys.selectedInterests, interests.join(','));
      return Result.success(null);
    } catch (error) {
      return Result.error(ServerFailure('Failed to save interests: $error', code: mapFirestoreError(error).code));
    }
  }

  @override
  Future<Result<void>> syncLocalInterests({required String userId}) async {
    try {
      final localInterests = PersonalizedInterestsCatalog.selectedFromLocal(_settingsLocal);
      final accountInterests =
          await _firestoreClient.getById<List<String>>(FirebaseCollections.usersV2, userId, (data, _) {
            final raw = data['interestCategories'];
            return raw is List ? raw.map((e) => e.toString()).toList(growable: false) : const <String>[];
          }, sourceTag: 'onboarding_v2.sync_local_interests.read') ??
          const <String>[];
      if (accountInterests.length >= OnboardingV2Config.minInterests) {
        await _settingsLocal.set(OnboardingV2Keys.selectedInterests, accountInterests.join(','));
      } else if (localInterests.isNotEmpty) {
        await _firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'interestCategories': localInterests,
          'onboardingV2.selectedInterests': localInterests,
        }, sourceTag: 'onboarding_v2.sync_local_interests.write');
      }
      return Result.success(null);
    } catch (error) {
      return Result.error(ServerFailure('Failed to sync local interests: $error'));
    }
  }

  @override
  Future<Result<void>> followCreators({
    required String currentUserId,
    required String currentUserEmail,
    required List<OnboardingStarterCreatorEntity> creators,
  }) async {
    bool followedOnServer = false;
    try {
      if (currentUserId.trim().isEmpty) {
        return Result.error(const ServerFailure('Failed to follow creators: invalid user id'));
      }
      await Future.wait(
        creators.where((creator) => creator.userId.isNotEmpty).map((creator) => _setFollow(creator.userId, true)),
      );
      followedOnServer = true;
      _trackCreatorFollows(creators, 'success');
      final followed = creators.map((c) => c.userId).where((id) => id.isNotEmpty).join(',');
      await _settingsLocal.set(OnboardingV2Keys.followedCreators, followed);
      return Result.success(null);
    } catch (error) {
      if (!followedOnServer) _trackCreatorFollows(creators, 'failure');
      return Result.error(ServerFailure('Failed to follow creators: $error', code: mapFirestoreError(error).code));
    }
  }

  void _trackCreatorFollows(List<OnboardingStarterCreatorEntity> creators, String result) {
    for (final creator in creators) {
      if (creator.userId.isEmpty) continue;
      unawaited(
        analytics.track(
          FollowResultEvent(
            action: 'follow',
            result: result,
            creatorId: creator.userId,
            source: 'onboarding_starter_pack',
          ),
        ),
      );
    }
  }

  @override
  Future<Result<OnboardingUserStatus>> fetchUserCompletionStatus({required String userId}) async {
    try {
      final status = await _firestoreClient.getById<OnboardingUserStatus>(FirebaseCollections.usersV2, userId, (
        data,
        _,
      ) {
        final interests = data['interestCategories'];
        final interestCount = interests is List ? interests.length : 0;
        final onboarding = data['onboardingV2'];
        return OnboardingUserStatus(
          hasInterests: interestCount >= OnboardingV2Config.minInterests,
          hasFollows: false,
          completed: onboarding is Map && onboarding['completed'] == true,
        );
      }, sourceTag: 'onboarding_v2.fetch_user_status');
      final follows = await _firestoreClient.query<String>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.profileFollowing(userId),
          sourceTag: 'onboarding_v2.fetch_user_follows',
          limit: OnboardingV2Config.minFollows,
          cachePolicy: FirestoreCachePolicy.memoryFirst,
        ),
        (_, docId) => docId,
      );
      final resolved = status ?? const OnboardingUserStatus(hasInterests: false, hasFollows: false);
      return Result.success(
        OnboardingUserStatus(
          hasInterests: resolved.hasInterests,
          hasFollows: follows.length >= OnboardingV2Config.minFollows,
          completed: resolved.completed,
        ),
      );
    } catch (error) {
      return Result.error(ServerFailure('Failed to fetch user completion status: $error'));
    }
  }

  @override
  Future<Result<void>> completeOnboarding({required String userId}) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
        'onboardingV2': <String, dynamic>{'completed': true, 'completedAt': now, 'version': 2},
      }, sourceTag: 'onboarding_v2.complete');
      await _settingsLocal.set(OnboardingV2Keys.onboardedNew, true);
      return Result.success(null);
    } catch (error) {
      return Result.error(ServerFailure('Failed to complete onboarding: $error', code: mapFirestoreError(error).code));
    }
  }
}

OnboardingStarterCreatorEntity _creatorFromCurationMap(Map<String, dynamic> map) {
  final String userId = (map['uid'] ?? map['userId'] ?? '').toString().trim();
  return OnboardingStarterCreatorEntity(
    userId: userId,
    email: map['email']?.toString() ?? '',
    name: '',
    photoUrl: '',
    previewUrls: const <String>[],
    rank: (map['rank'] as num?)?.toInt() ?? 0,
    followerCount: 0,
  );
}

Future<void> _callSetFollow(String targetUid, bool following) async {
  await appFunctions.httpsCallable('setFollow').call<Object?>(<String, Object?>{
    'targetUid': targetUid,
    'following': following,
  });
}

class _CreatorProfile {
  const _CreatorProfile({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.followerCount,
  });

  final String userId;
  final String name;
  final String photoUrl;
  final int followerCount;
}
