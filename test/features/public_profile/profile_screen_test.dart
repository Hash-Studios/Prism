import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/profile_user_fixture.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _FakeProfileRepository implements PublicProfileRepository {
  final StreamController<PublicProfileEntity?> profiles = StreamController<PublicProfileEntity?>.broadcast();

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) => profiles.stream;

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String email,
    required bool refresh,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> follow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> unfollow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) => throw UnimplementedError();

  @override
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> allEmails,
    required int page,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeEmails,
  }) => throw UnimplementedError();
}

const PublicProfileEntity _ana = PublicProfileEntity(
  id: 'u2',
  name: 'Ana Rivera',
  email: 'ana@example.com',
  username: 'ana_rivera',
  profilePhoto: '',
  bio: 'Makes calm gradients.',
  followers: <String>[],
  following: <String>[],
  links: <String, String>{},
  coverPhoto: '',
);

void main() {
  late _MockPublicProfileBloc bloc;
  late _FakeProfileRepository repository;
  late FakeUserBlockRepository blocks;

  setUp(() {
    bloc = _MockPublicProfileBloc();
    repository = _FakeProfileRepository();
    blocks = FakeUserBlockRepository.pending();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt
      ..registerFactory<PublicProfileBloc>(() => bloc)
      ..registerSingleton<PublicProfileRepository>(repository)
      ..registerSingleton<UserBlockRepository>(blocks);
    app_state.prismUser = profileUser(id: 'me', username: 'creator_01', bio: 'Hello', premium: true)
      ..name = 'Me Myself';
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(email: 'user@example.com', status: LoadStatus.success),
    );
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await repository.profiles.close();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, {String? identifier}) async {
    // A tall surface keeps the gallery header on screen.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(profileIdentifier: identifier)));
    // Glint and skeletons loop, so pump a bounded time instead of settling.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a guest is asked to sign in', (tester) async {
    app_state.prismUser = profileUser(loggedIn: false);

    await pumpScreen(tester);

    expect(find.text('Sign in to use your profile'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('own profile: identity, Pro tag, top buttons, completeness and an empty gallery', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Me Myself'), findsOneWidget);
    expect(find.text('@creator_01'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.byTooltip('Edit profile'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('Wallpapers'), findsOneWidget);
    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(find.text('Upload your first wallpaper to start your gallery.'), findsOneWidget);
  });

  testWidgets('the Menu button opens the drawer with account rows', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('another profile shows a skeleton while loading, then the profile with Follow', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');
    expect(find.bySemanticsLabel('Loading'), findsWidgets);
    expect(find.text('Ana Rivera'), findsNothing);

    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ana Rivera'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.text('Upload your first wallpaper to start your gallery.'), findsNothing);
  });

  testWidgets('another profile that has been deleted says it is not available', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');

    repository.profiles.add(null);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Profile not available'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('a failed profile stream shows an error with a retry', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');

    repository.profiles.addError(StateError('boom'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load this profile'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a blocked user shows the unblock shell instead of the profile', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    blocks.completeInitial(<String>{'ana@example.com'});
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('You blocked Ana Rivera'), findsOneWidget);
    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });
}
