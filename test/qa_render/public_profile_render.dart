@Tags(<String>['qa_render'])
library;

// Run: fvm flutter test test/qa_render/public_profile_render.dart --dart-define=QA_RENDER=true
// PNGs go to build/qa_render/.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/domain/usecases/public_profile_usecases.dart';
import 'package:Prism/features/public_profile/views/pages/followers_screen.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_user_block_repository.dart';
import '../support/favourite_test_scope.dart';
import '../support/profile_user_fixture.dart';
import 'qa_harness.dart';

const PublicProfileEntity _ava = PublicProfileEntity(
  id: 'creator-uid',
  name: 'Ava Lens',
  email: '',
  username: 'avalens',
  profilePhoto: 'https://qa.example/avatar.png',
  bio: 'Shooting neon cities at night.',
  links: <String, String>{},
  coverPhoto: 'https://qa.example/cover.png',
  followerCount: 1234,
  followingCount: 56,
  badges: <String>['early_adopter', 'creator', 'week_warrior'],
  frameId: 'frame_ring',
  nameGlowId: 'glow_aurora',
  xp: 4200,
);

final List<PublicProfileWallEntity> _walls = <PublicProfileWallEntity>[
  for (int i = 0; i < 6; i++)
    PublicProfileWallEntity(
      id: 'w$i',
      by: 'Ava Lens',
      wallpaperUrl: 'https://qa.example/w$i.png',
      wallpaperThumb: 'https://qa.example/w$i.png',
      creatorUid: 'creator-uid',
    ),
];

final List<UserSummaryEntity> _summaries = <UserSummaryEntity>[
  for (final (String, String) p in <(String, String)>[
    ('Ben Hart', 'benhart'),
    ('Cleo Park', 'cleopark'),
    ('Dev Rao', 'devrao'),
    ('Eli Stone', 'elistone'),
    ('Fay Moon', 'faymoon'),
  ])
    UserSummaryEntity(
      id: 'f-${p.$2}',
      email: '',
      name: p.$1,
      username: p.$2,
      profilePhoto: 'https://qa.example/${p.$2}.png',
      isFollowedByCurrentUser: p.$2 == 'cleopark',
    ),
];

class _FakeRepo implements PublicProfileRepository {
  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) => Stream<PublicProfileEntity?>.value(_ava);

  @override
  Future<Result<List<String>>> fetchRelationIds({required String profileUid, required UserRelationKind kind}) async =>
      Result.success(<String>[for (final UserSummaryEntity s in _summaries) s.id]);

  @override
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> userIds,
    required int page,
  }) async => Result.success((items: _summaries, hasMore: false));

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String userId,
    required bool refresh,
  }) async => Result.success((items: _walls, hasMore: false));

  @override
  Future<void> clearForUser(String userId) async {}

  @override
  Future<Result<void>> follow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) async => Result.success(null);

  @override
  Future<Result<void>> unfollow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) async => Result.success(null);

  @override
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeUserIds,
  }) async => Result.success(const <UserSummaryEntity>[]);
}

/// CachedNetworkImage ignores PrismImageCache, so seed the default cache (in a temp dir) with gradient PNGs.
Future<void> seedAvatarCache(QaShot shot, List<String> urls) async {
  await shot.tester.runAsync(() async {
    for (final String url in urls) {
      final FileInfo info = await PrismImageCache.instance.getFileStream(url).first as FileInfo;
      await DefaultCacheManager().putFile(url, await info.file.readAsBytes(), fileExtension: 'png');
    }
  });
}

// One dir for the whole run: DefaultCacheManager is a singleton and keeps its first path.
final Directory _cacheDir = Directory.systemTemp.createTempSync('profile_render_cache');

void setUpProfileDeps() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async => _cacheDir.path,
  );
  final _FakeRepo repo = _FakeRepo();
  AnalyticsRuntime.instance = FakeAppAnalytics();
  addTearDown(AnalyticsRuntime.reset);
  final FakeUserBlockRepository blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
  getIt
    ..registerSingleton<PublicProfileRepository>(repo)
    ..registerSingleton<UserBlockRepository>(blocks)
    ..registerFactory<PublicProfileBloc>(
      () => PublicProfileBloc(
        FetchPublicProfileWallsUseCase(repo),
        FollowUserUseCase(repo),
        UnfollowUserUseCase(repo),
        FetchUserSummariesPageUseCase(repo),
        SearchUsersByUsernameUseCase(repo),
      ),
    );
  app_state.prismUser = profileUser(id: 'me', username: 'me_viewer', bio: 'Hi')..name = 'Me Viewer';
}

Future<void> _save(QaShot shot, String name) async {
  final RenderRepaintBoundary render = shot.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final File file = File('build/qa_render/${name}_${shot.mode}.png');
  await shot.tester.runAsync(() async {
    final ui.Image image = await render.toImage(pixelRatio: 3);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpFavouriteCounts();
  setUpAll(() async {
    registerFallbackValue(ProfileRoute());
    if (qaRender) await loadFonts();
  });

  qaScreen('profile_other', (QaShot shot) async {
    await seedAvatarCache(shot, <String>[_ava.profilePhoto, _ava.coverPhoto]);
    await shot.pump(
      Builder(
        builder: (BuildContext c) => favouriteTestBuilder(c, const ProfileScreen(profileIdentifier: 'creator-uid')),
      ),
    );
    await shot.settle(frames: 30);
    await _save(shot, 'profile_other');
    await shot.tester.pump(const Duration(seconds: 11));
  }, setUpExtra: setUpProfileDeps);

  qaScreen('followers', (QaShot shot) async {
    await seedAvatarCache(shot, <String>[for (final UserSummaryEntity u in _summaries) u.profilePhoto]);
    await shot.pump(const FollowersScreen(userId: 'creator-uid'));
    await shot.settle(frames: 30);
    await _save(shot, 'followers');
    await shot.tester.pump(const Duration(seconds: 11));
  }, setUpExtra: setUpProfileDeps);
}
