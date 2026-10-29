import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/views/pages/auto_rotate_screen.dart';
import 'package:Prism/features/auto_rotate/views/widgets/auto_rotate_session_listener.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

class _MockFoldersBloc extends MockBloc<FoldersEvent, FoldersState> implements FoldersBloc {}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

class _MockStartupRepository extends Mock implements StartupRepository {}

class _RetryFoldersRepository implements FoldersRepository {
  int fetchCount = 0;

  @override
  Stream<FolderWriteFailure> get writeFailures => const Stream<FolderWriteFailure>.empty();

  @override
  int get writeRevision => 0;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async {
    fetchCount++;
    if (fetchCount == 1) return Result.error<List<FolderEntity>>(const NetworkFailure('offline'));
    return Result.success<List<FolderEntity>>(const <FolderEntity>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _MockAutoRotateBloc autoRotateBloc;
  late _MockFavouriteWallsBloc favouriteWallsBloc;
  late _MockFoldersBloc foldersBloc;
  late _MockSessionBloc sessionBloc;

  setUpAll(() {
    registerFallbackValue(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: false));
  });

  setUp(() async {
    await getIt.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    autoRotateBloc = _MockAutoRotateBloc();
    favouriteWallsBloc = _MockFavouriteWallsBloc();
    foldersBloc = _MockFoldersBloc();
    sessionBloc = _MockSessionBloc();
    final _MockStartupRepository startupRepository = _MockStartupRepository();
    when(() => favouriteWallsBloc.state).thenReturn(FavouriteWallsState.initial().copyWith(status: LoadStatus.success));
    when(() => sessionBloc.state).thenReturn(SessionState.initial().copyWith(status: LoadStatus.success));
    when(() => autoRotateBloc.state).thenReturn(_proState());
    when(() => foldersBloc.state).thenReturn(
      FoldersState.initial().copyWith(
        status: LoadStatus.success,
        userId: 'u1',
        folders: <FolderEntity>[_folder('f1', 'Calm', itemCount: 3), _folder('f2', 'Focus', itemCount: 1)],
      ),
    );
    when(() => startupRepository.currentConfig).thenReturn(
      const StartupConfigEntity(
        topImageLink: '',
        bannerText: '',
        bannerTextOn: false,
        bannerUrl: '',
        obsoleteAppVersion: '',
        verifiedUsers: <String>[],
        premiumCollections: <String>[],
        aiEnabled: false,
        aiRolloutPercent: 0,
        aiSubmitEnabled: false,
        aiVariationsEnabled: false,
        useRcPaywalls: false,
        onboardingV2Enabled: false,
      ),
    );
    getIt.registerSingleton<StartupRepository>(startupRepository);
    getIt.registerFactory<AutoRotateBloc>(() => autoRotateBloc);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async => true,
    );
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, {String? folderId, String? folderName}) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AutoRotateBloc>.value(value: autoRotateBloc),
            BlocProvider<FavouriteWallsBloc>.value(value: favouriteWallsBloc),
            BlocProvider<FoldersBloc>.value(value: foldersBloc),
            BlocProvider<SessionBloc>.value(value: sessionBloc),
          ],
          child: AutoRotateSessionListener(
            child: AutoRotateScreen(folderId: folderId, folderName: folderName),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpScreenWithFolders(WidgetTester tester, FoldersBloc folders) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AutoRotateBloc>.value(value: autoRotateBloc),
            BlocProvider<FavouriteWallsBloc>.value(value: favouriteWallsBloc),
            BlocProvider<FoldersBloc>.value(value: folders),
            BlocProvider<SessionBloc>.value(value: sessionBloc),
          ],
          child: AutoRotateSessionListener(child: const AutoRotateScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the Folder source opens a picker with each folder and its count, and sends the pick', (tester) async {
    await pumpScreen(tester);
    // The folder sheet lists folders only for a signed-in user, so sign in after the screen starts.
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';

    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a folder'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('3 wallpapers'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('1 wallpaper'), findsOneWidget);

    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    verify(() => autoRotateBloc.add(const AutoRotateEvent.folderChosen(folderId: 'f1', name: 'Calm'))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the folder picker does not apply an old owner folder after an account switch', (tester) async {
    await pumpScreen(tester);
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';

    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.folderChosen(folderId: 'f1', name: 'Calm')));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the folder picker explains that sign-in is required instead of loading forever', (tester) async {
    when(() => foldersBloc.state).thenReturn(FoldersState.initial());
    await pumpScreen(tester);

    await tester.tap(find.text('Folder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sign in to use folders'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the folder picker retries a failed load and then shows the empty state', (tester) async {
    final _RetryFoldersRepository repository = _RetryFoldersRepository();
    final FoldersBloc folders = FoldersBloc(repository);
    addTearDown(folders.close);
    await pumpScreenWithFolders(tester, folders);
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';

    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();
    expect(repository.fetchCount, 1);
    expect(folders.state.status, LoadStatus.failure);
    expect(find.text('Could not load this folder.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.fetchCount, 2);
    expect(find.text('You have no folders yet. Save a wallpaper to a folder, then pick it here.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the rotate offer confirms the folder and enables it atomically', (tester) async {
    await pumpScreen(tester, folderId: 'f1', folderName: 'Calm');

    expect(find.text('Rotate Calm?'), findsOneWidget);
    await tester.tap(find.text('Rotate this folder'));
    await tester.pump();

    verify(
      () => autoRotateBloc.add(const AutoRotateEvent.folderChosen(folderId: 'f1', name: 'Calm', enable: true)),
    ).called(1);
    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.toggled(true)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the rotate offer cannot be confirmed after its owner changes', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    final StreamController<SessionState> sessions = StreamController<SessionState>();
    addTearDown(sessions.close);
    final SessionState ownerSession = SessionState.initial().copyWith(
      status: LoadStatus.success,
      session: const SessionEntity(userId: 'u1', loggedIn: true, premium: false, subscriptionTier: 'free'),
    );
    when(() => sessionBloc.state).thenReturn(ownerSession);
    when(
      () => favouriteWallsBloc.state,
    ).thenReturn(FavouriteWallsState.initial().copyWith(status: LoadStatus.success, userId: 'u1'));
    whenListen(sessionBloc, sessions.stream, initialState: ownerSession);
    await pumpScreen(tester, folderId: 'f1', folderName: 'Calm');
    expect(find.text('Rotate Calm?'), findsOneWidget);

    sessions.add(
      SessionState.initial().copyWith(
        status: LoadStatus.success,
        session: const SessionEntity(userId: 'u2', loggedIn: true, premium: false, subscriptionTier: 'free'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Rotate Calm?'), findsNothing);
    verifyNever(
      () => autoRotateBloc.add(const AutoRotateEvent.folderChosen(folderId: 'f1', name: 'Calm', enable: true)),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Not now hides the rotate offer without changing rotation', (tester) async {
    await pumpScreen(tester, folderId: 'f1', folderName: 'Calm');

    await tester.tap(find.text('Not now'));
    await tester.pump();

    expect(find.text('Rotate Calm?'), findsNothing);
    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.folderChosen(folderId: 'f1', name: 'Calm')));
    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.toggled(true)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final (AutoRotateStopReason reason, String message) in <(AutoRotateStopReason, String)>[
    (AutoRotateStopReason.folderDeleted, 'Auto-rotate is off because the folder Calm was deleted.'),
    (AutoRotateStopReason.folderEmpty, 'Auto-rotate is off because the folder Calm has fewer than 2 wallpapers.'),
  ]) {
    testWidgets('a folder stop ($reason) shows its message once and is acknowledged', (tester) async {
      final List<MethodCall> toastCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        (call) async {
          toastCalls.add(call);
          return true;
        },
      );
      final StreamController<AutoRotateState> states = StreamController<AutoRotateState>.broadcast();
      addTearDown(states.close);
      whenListen(autoRotateBloc, states.stream, initialState: _proState());

      await pumpScreen(tester);
      states.add(_proState().copyWith(folderStop: (reason: reason, folderName: 'Calm')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final Iterable<MethodCall> shown = toastCalls.where((call) => call.method == 'showToast');
      expect(shown, hasLength(1));
      expect((shown.single.arguments as Map<Object?, Object?>)['msg'], message);
      verify(() => autoRotateBloc.add(const AutoRotateEvent.folderStopAcknowledged())).called(1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}

FolderEntity _folder(String id, String name, {int itemCount = 0}) {
  final DateTime at = DateTime.utc(2026, 10);
  return FolderEntity(
    id: id,
    ownerId: 'u1',
    name: name,
    createdAt: at,
    updatedAt: at,
    itemCount: itemCount,
    covers: const <String>[],
  );
}

AutoRotateState _proState() => AutoRotateState.initial().copyWith(loaded: true, isPro: true, favouriteCount: 5);
