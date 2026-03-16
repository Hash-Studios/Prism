import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: OnboardingV2Repository)
class OnboardingV2RepositoryImpl implements OnboardingV2Repository {
  OnboardingV2RepositoryImpl(this._remoteConfig, this._firestoreClient, this._settingsLocal);

  final FirebaseRemoteConfig _remoteConfig;
  final FirestoreClient _firestoreClient;
  final SettingsLocalDataSource _settingsLocal;

  @override
  Future<Result<List<OnboardingStarterCreatorEntity>>> fetchStarterPack() async {
    try {
      final raw = _remoteConfig.getString(OnboardingV2Config.remoteConfigStarterPackKey);
      if (raw.isEmpty) {
        return Result.success(<OnboardingStarterCreatorEntity>[]);
      }
      final decoded = json.decode(raw);
      if (decoded is! List) {
        return Result.success(<OnboardingStarterCreatorEntity>[]);
      }

      // Parse curation list — only email + rank are required in Remote Config now.
      // Legacy format (with embedded profile data) is also supported for backwards
      // compatibility during the transition period.
      final curationEntries = decoded
          .whereType<Map<String, dynamic>>()
          .map(OnboardingStarterCreatorEntity.fromCurationMap)
          .where((e) => e.email.isNotEmpty)
          .toList(growable: false);

      if (curationEntries.isEmpty) {
        return Result.success(<OnboardingStarterCreatorEntity>[]);
      }

      // Fetch profile + last 3 wallpapers for every creator in parallel.
      final enriched = await Future.wait(curationEntries.map((entry) => _enrichCreator(entry)));

      return Result.success(enriched);
    } catch (error) {
      return Result.error(ServerFailure('Failed to fetch starter pack: $error'));
    }
  }

  /// Fetches live profile data and the last 5 wallpapers for [entry] from Firestore.
  /// Gracefully falls back to the original (empty) entry values on any error.
  Future<OnboardingStarterCreatorEntity> _enrichCreator(OnboardingStarterCreatorEntity entry) async {
    final results = await Future.wait([_fetchUserProfile(entry.email), _fetchPreviewUrls(entry.email)]);

    final profile = results[0] as _CreatorProfile?;
    final previewUrls = (results[1]! as List<dynamic>).cast<String>();

    return OnboardingStarterCreatorEntity(
      userId: profile?.userId ?? entry.userId,
      email: entry.email,
      name: profile?.name ?? entry.name,
      photoUrl: profile?.photoUrl ?? entry.photoUrl,
      bio: profile?.bio ?? entry.bio,
      followerCount: profile?.followerCount ?? entry.followerCount,
      previewUrls: previewUrls,
      rank: entry.rank,
    );
  }

  Future<_CreatorProfile?> _fetchUserProfile(String email) async {
    try {
      final rows = await _firestoreClient.query<_CreatorProfile?>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.usersV2,
          sourceTag: 'onboarding_v2.fetch_creator_profile',
          filters: [FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email)],
          limit: 1,
          cachePolicy: FirestoreCachePolicy.staleWhileRevalidate,
          dedupeWindowMs: 60000,
        ),
        (data, docId) {
          final name = data['name']?.toString() ?? '';
          final photoUrl = data['profilePhoto']?.toString() ?? '';
          final bio = data['bio']?.toString() ?? '';
          final rawFollowers = data['followers'];
          final followerCount = rawFollowers is List ? rawFollowers.length : 0;
          return _CreatorProfile(userId: docId, name: name, photoUrl: photoUrl, bio: bio, followerCount: followerCount);
        },
      );
      return rows.firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _fetchPreviewUrls(String email) async {
    try {
      final rows = await _firestoreClient.query<String>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'onboarding_v2.fetch_creator_walls',
          filters: [
            FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
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
          return thumb.isNotEmpty ? thumb : url;
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
      return Result.error(ServerFailure('Failed to save interests: $error'));
    }
  }

  @override
  Future<Result<void>> followCreators({
    required String currentUserId,
    required String currentUserEmail,
    required List<OnboardingStarterCreatorEntity> creators,
  }) async {
    try {
      await _firestoreClient.runBatch((batch) async {
        batch.updateDoc(FirebaseCollections.usersV2, currentUserId, <String, dynamic>{
          'following': FirestoreSentinels.arrayUnion(creators.map((c) => c.email).toList()),
        });
        for (final creator in creators) {
          if (creator.userId.isEmpty) {
            continue;
          }
          batch.updateDoc(FirebaseCollections.usersV2, creator.userId, <String, dynamic>{
            'followers': FirestoreSentinels.arrayUnion([currentUserEmail]),
          });
        }
      }, sourceTag: 'onboarding_v2.follow_creators');
      final followed = creators.map((c) => c.email).join(',');
      await _settingsLocal.set(OnboardingV2Keys.followedCreators, followed);
      return Result.success(null);
    } catch (error) {
      return Result.error(ServerFailure('Failed to follow creators: $error'));
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
        final following = data['following'];
        final interestCount = interests is List ? interests.length : 0;
        final followCount = following is List ? following.length : 0;
        return OnboardingUserStatus(
          hasInterests: interestCount >= OnboardingV2Config.minInterests,
          hasFollows: followCount >= OnboardingV2Config.minFollows,
        );
      }, sourceTag: 'onboarding_v2.fetch_user_status');
      return Result.success(status ?? const OnboardingUserStatus(hasInterests: false, hasFollows: false));
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
      return Result.error(ServerFailure('Failed to complete onboarding: $error'));
    }
  }
}

class _CreatorProfile {
  const _CreatorProfile({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.bio,
    required this.followerCount,
  });

  final String userId;
  final String name;
  final String photoUrl;
  final String bio;
  final int followerCount;
}
