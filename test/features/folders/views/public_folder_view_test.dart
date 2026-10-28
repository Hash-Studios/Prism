import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/folders/biz/public_folder_cubit.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/public_folder_view.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
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
  PublicFolderFailure? followFailure;

  /// One entry per setFollowing call: the folder id and the requested state.
  final List<(String, bool)> followCalls = <(String, bool)>[];

  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => Result.success(folder);

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async => Result.success(wallIds);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId) async =>
      Result.success(const <PublicFolderEntity>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId) async =>
      Result.success(const <PublicFolderEntity>[]);

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) async => Result.success(following);

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
  @override
  Future<List<MoodList>> fetchMoods() async => const <MoodList>[];

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async =>
      const <PrismWallpaper>[];

  @override
  Stream<void> watchVisibilityChanges() => const Stream<void>.empty();
}

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

  testWidgets('a refused follow puts the button back to Follow', (tester) async {
    final repo = _FakePublicFoldersRepository()
      ..folder = _folder()
      ..followFailure = const PublicFolderFailure('refused', refusal: PublicFolderRefusal.unavailable);
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
