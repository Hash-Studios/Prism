import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/folders/biz/public_folder_cubit.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/public_folder_view.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePublicFoldersRepository implements PublicFoldersRepository {
  PublicFolderEntity? folder;
  List<String> wallIds = const <String>[];
  bool following = false;
  Future<Result<PublicFolderEntity?>>? nextFolderRead;
  int folderReads = 0;
  PublicFolderFailure? followFailure;

  /// One entry per setFollowing call: the folder id and the requested state.
  final List<(String, bool)> followCalls = <(String, bool)>[];
  final List<(String, String)> followQueries = <(String, String)>[];

  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async {
    folderReads++;
    final Future<Result<PublicFolderEntity?>>? pending = nextFolderRead;
    nextFolderRead = null;
    return pending ?? Result.success(folder);
  }

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async => Result.success(wallIds);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId) async =>
      Result.success(const <PublicFolderEntity>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId) async =>
      Result.success(const <PublicFolderEntity>[]);

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) async {
    followQueries.add((folderId, userId));
    return Result.success(following);
  }

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async {
    followCalls.add((folderId, following));
    final PublicFolderFailure? failure = followFailure;
    if (failure != null) return Result.error(failure);
    this.following = following;
    return Result.success<void>(null);
  }

  @override
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic}) async => Result.success(isPublic);
}

class _FakeMoodRepository implements MoodRepository {
  _FakeMoodRepository({this.visibility = const Stream<void>.empty()});

  final Stream<void> visibility;

  @override
  Future<List<MoodList>> fetchMoods() async => const <MoodList>[];

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async =>
      const <PrismWallpaper>[];

  @override
  Stream<void> watchVisibilityChanges() => visibility;
}

class _MockSessionRepository extends Mock implements SessionRepository {}

PublicFolderEntity _folder({String ownerId = 'owner', int followerCount = 1}) => PublicFolderEntity(
  id: 'f1',
  ownerId: ownerId,
  name: 'Night Owl',
  itemCount: 0,
  covers: const <String>[],
  followerCount: followerCount,
);

late _MockStackRouter _router;

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme ?? kLightTheme,
  home: StackRouterScope(controller: _router, stateHash: 0, child: child),
);

// The page loads from the fake repositories; pump a fixed time rather than settle.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    _router = _MockStackRouter();
    when(() => _router.stack).thenReturn(const <AutoRoutePage<dynamic>>[]);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'viewer';
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('a viewer follows a public folder and the button and count change', (tester) async {
    final repo = _FakePublicFoldersRepository()..folder = _folder();
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    expect(find.text('Night Owl'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.textContaining('1 follower'), findsOneWidget);

    await tester.tap(find.text('Follow'));
    await _settle(tester);

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(find.textContaining('2 followers'), findsOneWidget);
    expect(repo.followCalls, <(String, bool)>[('f1', true)]);

    // The same page in dark theme keeps the followed state.
    await tester.pumpWidget(
      _host(
        PublicFolderView(folderId: 'f1', cubit: cubit),
        theme: kDarkTheme,
      ),
    );
    await _settle(tester);
    expect(find.text('Following'), findsOneWidget);
    expect(find.textContaining('2 followers'), findsOneWidget);
  });

  testWidgets('a viewer who already follows sees Following, and tapping it unfollows', (tester) async {
    final repo = _FakePublicFoldersRepository()
      ..folder = _folder()
      ..following = true;
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);

    await tester.tap(find.text('Following'));
    await _settle(tester);

    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
    expect(repo.followCalls, <(String, bool)>[('f1', false)]);
  });

  testWidgets('a mounted public folder reloads follow state when the session account changes', (tester) async {
    final repo = _FakePublicFoldersRepository()
      ..folder = _folder()
      ..following = true;
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    final _MockSessionRepository session = _MockSessionRepository();
    final StreamController<PrismUsersV2> sessions = StreamController<PrismUsersV2>.broadcast(sync: true);
    addTearDown(sessions.close);
    PrismUsersV2 currentUser = app_constants.createGuestPrismUser()..id = 'viewer';
    when(() => session.currentUser).thenAnswer((_) => currentUser);
    when(() => session.watchCurrentUser()).thenAnswer((_) async* {
      yield currentUser;
      yield* sessions.stream;
    });
    getIt.registerSingleton<SessionRepository>(session);
    addTearDown(() => getIt.unregister<SessionRepository>());
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    expect(repo.followQueries, <(String, String)>[('f1', 'viewer')]);
    expect(find.text('Following'), findsOneWidget);
    currentUser = app_constants.createGuestPrismUser()..id = 'viewer-2';
    repo.following = false;
    sessions.add(currentUser);
    await _settle(tester);

    expect(repo.followQueries, <(String, String)>[('f1', 'viewer'), ('f1', 'viewer-2')]);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('an old account load cannot overwrite the folder after the session changes', (tester) async {
    final repo = _FakePublicFoldersRepository()..folder = _folder();
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    final _MockSessionRepository session = _MockSessionRepository();
    final StreamController<PrismUsersV2> sessions = StreamController<PrismUsersV2>.broadcast(sync: true);
    addTearDown(sessions.close);
    PrismUsersV2 currentUser = app_constants.createGuestPrismUser()..id = 'viewer';
    when(() => session.currentUser).thenAnswer((_) => currentUser);
    when(() => session.watchCurrentUser()).thenAnswer((_) async* {
      yield currentUser;
      yield* sessions.stream;
    });
    getIt.registerSingleton<SessionRepository>(session);
    addTearDown(() => getIt.unregister<SessionRepository>());
    final Completer<Result<PublicFolderEntity?>> oldRead = Completer<Result<PublicFolderEntity?>>();
    repo.nextFolderRead = oldRead.future;
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));

    currentUser = app_constants.createGuestPrismUser()..id = 'viewer-2';
    sessions.add(currentUser);
    await _settle(tester);
    oldRead.complete(Result.success(null));
    await _settle(tester);

    expect(repo.followQueries, <(String, String)>[('f1', 'viewer-2')]);
    expect(find.text('Night Owl'), findsOneWidget);
  });

  testWidgets('a temporary refused follow puts the button back to Follow', (tester) async {
    final repo = _FakePublicFoldersRepository()
      ..folder = _folder()
      ..followFailure = const PublicFolderFailure('refused', refusal: PublicFolderRefusal.limit);
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    await tester.tap(find.text('Follow'));
    await _settle(tester);

    expect(repo.followCalls, <(String, bool)>[('f1', true)]);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('an unavailable follow hides the stale header and Share action', (tester) async {
    final repo = _FakePublicFoldersRepository()
      ..folder = _folder()
      ..followFailure = const PublicFolderFailure('private', refusal: PublicFolderRefusal.unavailable);
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);
    expect(find.byTooltip('Share folder'), findsOneWidget);

    await tester.tap(find.text('Follow'));
    await _settle(tester);

    expect(find.text('This folder is private or no longer exists'), findsOneWidget);
    expect(find.text('Night Owl'), findsNothing);
    expect(find.byTooltip('Share folder'), findsNothing);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('blocking the owner while the folder is open hides its header and Share action', (tester) async {
    final StreamController<void> visibility = StreamController<void>.broadcast(sync: true);
    addTearDown(visibility.close);
    final repo = _FakePublicFoldersRepository()..folder = _folder();
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository(visibility: visibility.stream));
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);
    expect(find.text('Night Owl'), findsOneWidget);
    expect(find.byTooltip('Share folder'), findsOneWidget);

    repo.folder = null;
    visibility.add(null);
    await _settle(tester);

    expect(find.text('This folder is private or no longer exists'), findsOneWidget);
    expect(find.text('Night Owl'), findsNothing);
    expect(find.byTooltip('Share folder'), findsNothing);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('the owner sees no follow button but can share the folder', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'owner';
    final repo = _FakePublicFoldersRepository()..folder = _folder();
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    expect(find.text('Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
    expect(find.byTooltip('Share folder'), findsOneWidget);
  });

  testWidgets('a private or removed folder shows the unavailable state and no follow button', (tester) async {
    final repo = _FakePublicFoldersRepository()..folder = null;
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    expect(find.text('This folder is private or no longer exists'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('a folder hidden by a block in either direction shows the unavailable state', (tester) async {
    // The rules refuse the read in both block directions, so the repository reads no folder.
    final repo = _FakePublicFoldersRepository()..folder = null;
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    expect(find.text('This folder is private or no longer exists'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('a public folder with no walls shows the empty state', (tester) async {
    final repo = _FakePublicFoldersRepository()..folder = _folder();
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    expect(find.text('No wallpapers here yet'), findsOneWidget);
  });

  testWidgets('resuming the app reloads the open public folder', (tester) async {
    final repo = _FakePublicFoldersRepository()..folder = _folder();
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);
    expect(repo.folderReads, 1);

    repo.folder = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    expect(repo.folderReads, 2);
    expect(find.text('Night Owl'), findsNothing);
    expect(find.text('This folder is private or no longer exists'), findsOneWidget);
  });

  testWidgets('the share button has a tooltip and the owner row is labelled', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final repo = _FakePublicFoldersRepository()..folder = _folder();
    final PublicFolderCubit cubit = PublicFolderCubit(repo, _FakeMoodRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(PublicFolderView(folderId: 'f1', cubit: cubit)));
    await _settle(tester);

    expect(find.byTooltip('Share folder'), findsOneWidget);
    // No public profile repository is registered in tests, so the owner falls back to the creator name.
    expect(find.bySemanticsLabel('By Prism creator'), findsOneWidget);
    handle.dispose();
  });
}
