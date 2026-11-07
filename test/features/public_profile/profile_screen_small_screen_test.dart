import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';
import '../creator_directory/creator_directory_test_support.dart';

// Issue #548: the profile screen must not overflow on a 320 logical-pixel phone at 2x text.

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _FakeProfileRepository implements PublicProfileRepository {
  final StreamController<PublicProfileEntity?> profiles = StreamController<PublicProfileEntity?>.broadcast();
  final List<String> watchedIdentifiers = <String>[];

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) {
    watchedIdentifiers.add(identifier);
    return profiles.stream;
  }

  @override
  Future<Result<List<String>>> fetchRelationIds({required String profileUid, required UserRelationKind kind}) =>
      throw UnimplementedError();

  @override
  Future<void> clearForUser(String userId) async {}

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String userId,
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
    required List<String> userIds,
    required int page,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeUserIds,
  }) => throw UnimplementedError();
}

const String _longName = 'Maximiliana Alexandria Fernandez-Montgomery of the Northern Coastal Region';
const String _longUsername = 'maximiliana_alexandria_fernandez_montgomery_northern_coast_01';
const String _longBio = 'A long profile biography that should remain readable at larger text sizes.';
const Map<String, String> _fourLinks = <String, String>{
  'github': 'https://github.com/a',
  'twitter': 'https://twitter.com/a',
  'instagram': 'https://instagram.com/a',
  'telegram': 'https://t.me/a',
};

const PublicProfileEntity _longProfile = PublicProfileEntity(
  id: 'u2',
  name: _longName,
  email: '',
  username: _longUsername,
  profilePhoto: '',
  bio: _longBio,
  links: _fourLinks,
  coverPhoto: '',
);

void main() {
  setUpFavouriteCounts();
  setUp(() => getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore())));
  tearDown(() async {
    if (getIt.isRegistered<SettingsLocalDataSource>()) await getIt.unregister<SettingsLocalDataSource>();
  });
  late _MockPublicProfileBloc bloc;
  late _FakeProfileRepository repository;
  late FakeUserBlockRepository blocks;
  void Function(FlutterErrorDetails)? savedOnError;

  setUp(() {
    savedOnError = FlutterError.onError;
    bloc = _MockPublicProfileBloc();
    repository = _FakeProfileRepository();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt
      ..registerFactory<PublicProfileBloc>(() => bloc)
      ..registerSingleton<PublicProfileRepository>(repository)
      ..registerSingleton<UserBlockRepository>(blocks);
    registerCreatorDirectoryFakes(profileBloc: false);
    app_state.prismUser = profileUser(id: 'me', username: 'creator_01', bio: 'Hello', premium: true)
      ..name = 'Me Myself';
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(profileId: 'me', status: LoadStatus.success),
    );
  });

  tearDown(() async {
    FlutterError.onError = savedOnError;
    AnalyticsRuntime.reset();
    await repository.profiles.close();
    await getIt.reset();
  });

  // Pumps ProfileScreen on a 320 x 568 logical-pixel surface at 2x text scale.
  Future<void> pumpSmallScreen(WidgetTester tester, {required bool isDark, String? identifier}) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: ProfileScreen(profileIdentifier: identifier),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: favouriteTestBuilder(context, child),
        ),
      ),
    );
    // Glint and skeletons loop, so pump a bounded time instead of settling.
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Records every FlutterError, and still forwards it so tester.takeException() keeps working.
  List<String> captureFlutterErrors() {
    final List<String> messages = <String>[];
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      messages.add(details.toString());
      previous?.call(details);
    };
    return messages;
  }

  void expectNoOverflow(List<String> errors) {
    final List<String> overflows = errors.where((String message) => message.contains('overflowed')).toList();
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  }

  for (final bool isDark in <bool>[false, true]) {
    final String themeName = isDark ? 'dark' : 'light';

    testWidgets('another profile with 4 links, long name and long username fits 320 wide at 2x text, $themeName', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<PublicProfileState>.empty(),
        initialState: PublicProfileState.initial().copyWith(profileId: 'u2', status: LoadStatus.success),
      );
      final List<String> errors = captureFlutterErrors();

      await pumpSmallScreen(tester, isDark: isDark, identifier: 'u2');
      repository.profiles.add(_longProfile);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_longName), findsWidgets);
      expect(find.byIcon(JamIcons.gift), findsOneWidget);
      expect(find.byIcon(JamIcons.user_plus), findsOneWidget);
      expect(find.byWidgetPredicate((Widget widget) => widget is PopupMenuButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoOverflow(errors);
    });

    testWidgets('own profile with 4 links, long name and long username fits 320 wide at 2x text, $themeName', (
      tester,
    ) async {
      app_state.prismUser = profileUser(id: 'me', username: _longUsername, bio: _longBio, links: _fourLinks)
        ..name = _longName;
      final List<String> errors = captureFlutterErrors();

      await pumpSmallScreen(tester, isDark: isDark);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_longName), findsWidgets);
      expect(find.byIcon(JamIcons.pencil), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoOverflow(errors);
    });
  }
}
