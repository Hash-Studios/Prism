import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/creator_directory/biz/creator_directory_cubit.dart';
import 'package:Prism/features/creator_directory/biz/creator_directory_opt_out_cubit.dart';
import 'package:Prism/features/creator_directory/biz/followed_by_cubit.dart';
import 'package:Prism/features/creator_directory/biz/similar_creators_offer_session.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';
import '../../support/profile_user_fixture.dart';

export 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';

/// Pages keyed by (category, afterRank). A missing key returns an empty last page.
class FakeCreatorDirectoryRepository implements CreatorDirectoryRepository {
  final Map<(String?, int?), CreatorPage> pages = <(String?, int?), CreatorPage>{};

  /// A fetch for a key waits on its completer. Leave it open to keep the page loading.
  final Map<(String?, int?), Completer<void>> gates = <(String?, int?), Completer<void>>{};

  /// When set, every fetchPage throws this.
  Object? fetchError;

  /// Uids the viewer follows.
  Set<String> followed = <String>{};

  final List<({String? category, int? afterRank})> fetchCalls = <({String? category, int? afterRank})>[];
  final List<List<String>> followedAmongCalls = <List<String>>[];

  @override
  Future<CreatorPage> fetchPage({
    String? category,
    int? afterRank,
    int limit = CreatorDirectoryRepository.pageSize,
  }) async {
    fetchCalls.add((category: category, afterRank: afterRank));
    final Completer<void>? gate = gates[(category, afterRank)];
    if (gate != null) await gate.future;
    final Object? error = fetchError;
    if (error != null) throw error;
    return pages[(category, afterRank)] ?? const CreatorPage(creators: <DirectoryCreator>[], nextRank: null);
  }

  @override
  Future<Set<String>> followedAmong(List<String> uids) async {
    followedAmongCalls.add(List<String>.of(uids));
    return uids.where(followed.contains).toSet();
  }

  @override
  Future<List<DirectoryCreator>> similarTo(String uid, {int limit = 6}) async => const <DirectoryCreator>[];

  @override
  Future<FollowedBy> followedBy(String creatorUid) async => FollowedBy.none;

  bool optedOut = false;

  @override
  Future<bool> isOptedOut() async => optedOut;

  bool failOptOut = false;

  @override
  Future<void> setOptedOut(bool optOut) async {
    if (failOptOut) throw StateError('offline');
    optedOut = optOut;
  }
}

class EmptyCreatorBlocks extends Fake implements UserBlockRepository {
  @override
  BlockedCreators get blockedCreators => KnownBlockedCreators(<String>[]);

  @override
  Stream<BlockedCreators> watchBlockedCreators() => const Stream<BlockedCreators>.empty();
}

class MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

MockPublicProfileBloc publicProfileBlocWith({PublicProfileState? state}) {
  final MockPublicProfileBloc bloc = MockPublicProfileBloc();
  whenListen(bloc, const Stream<PublicProfileState>.empty(), initialState: state ?? PublicProfileState.initial());
  return bloc;
}

/// A creator with [wallCount] walls. Walls have no image URLs, so no network request runs.
DirectoryCreator directoryCreator(
  String uid, {
  String? name,
  int rank = 1,
  int followers = 2,
  List<String> categories = const <String>[],
  int wallCount = 4,
}) {
  final List<PrismWallpaper> walls = <PrismWallpaper>[
    for (int i = 0; i < wallCount; i++)
      PrismWallpaper(
        core: WallpaperCore(id: '$uid-wall-$i', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
        firestoreDocumentId: '$uid-wall-$i',
      ),
  ];
  return DirectoryCreator(
    entry: CreatorDirectoryEntry(
      uid: uid,
      name: name ?? 'Creator $uid',
      username: uid,
      photoUrl: '',
      followerCount: followers,
      wallIds: walls.map((w) => w.id).toList(growable: false),
      categories: categories,
      similar: const <String>[],
      rank: rank,
    ),
    walls: walls,
  );
}

CreatorPage creatorPage(List<DirectoryCreator> creators, {int? nextRank}) =>
    CreatorPage(creators: creators, nextRank: nextRank);

List<String> uidsOf(List<DirectoryCreator> creators) => creators.map((c) => c.uid).toList(growable: false);

/// Signed-in viewer and a fresh in-memory analytics sink. Call from setUp.
void setUpCreatorDirectoryGlobals() {
  app_state.prismUser = profileUser();
  AnalyticsRuntime.instance = FakeAppAnalytics();
}

/// Restores the guest user and clears getIt. Call from tearDown.
Future<void> resetCreatorDirectoryGlobals() async {
  app_state.prismUser = app_constants.createGuestPrismUser();
  AnalyticsRuntime.reset();
  await getIt.reset();
}

Future<void> pumpCreators(
  WidgetTester tester,
  Widget home, {
  required FakeCreatorDirectoryRepository repository,
  required PublicProfileBloc profileBloc,
}) async {
  getIt.registerSingleton<UserBlockRepository>(EmptyCreatorBlocks());
  getIt.registerFactory<PublicProfileBloc>(() => profileBloc);
  registerCreatorDirectoryFakes(repository: repository, profileBloc: false);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: kLightTheme,
      builder: favouriteTestBuilder,
      home: home,
    ),
  );
}

/// Registers the creator directory fakes that the Home feed, search, profile and settings widgets read.
/// Each registration is skipped when the type is already registered. Call from setUp, after any getIt reset.
void registerCreatorDirectoryFakes({FakeCreatorDirectoryRepository? repository, bool profileBloc = true}) {
  final FakeCreatorDirectoryRepository fake = repository ?? FakeCreatorDirectoryRepository();
  if (!getIt.isRegistered<CreatorDirectoryRepository>()) {
    getIt.registerSingleton<CreatorDirectoryRepository>(fake);
  }
  if (!getIt.isRegistered<CreatorDirectoryCubit>()) {
    getIt.registerFactory<CreatorDirectoryCubit>(
      () => CreatorDirectoryCubit(
        getIt<CreatorDirectoryRepository>(),
        getIt.isRegistered<UserBlockRepository>() ? getIt<UserBlockRepository>() : EmptyCreatorBlocks(),
      ),
    );
  }
  if (!getIt.isRegistered<FollowedByCubit>()) {
    getIt.registerFactory<FollowedByCubit>(() => FollowedByCubit(getIt<CreatorDirectoryRepository>()));
  }
  if (!getIt.isRegistered<CreatorDirectoryOptOutCubit>()) {
    getIt.registerFactory<CreatorDirectoryOptOutCubit>(
      () => CreatorDirectoryOptOutCubit(getIt<CreatorDirectoryRepository>()),
    );
  }
  if (!getIt.isRegistered<SimilarCreatorsOfferSession>()) {
    getIt.registerLazySingleton<SimilarCreatorsOfferSession>(
      () => SimilarCreatorsOfferSession(getIt<CreatorDirectoryRepository>()),
    );
  }
  if (profileBloc && !getIt.isRegistered<PublicProfileBloc>()) {
    final MockPublicProfileBloc bloc = publicProfileBlocWith();
    getIt.registerFactory<PublicProfileBloc>(() => bloc);
  }
}
