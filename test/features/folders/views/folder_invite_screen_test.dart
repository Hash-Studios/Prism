import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/domain/entities/folder_invite.dart';
import 'package:Prism/features/folders/domain/repositories/shared_folders_repository.dart';
import 'package:Prism/features/folders/views/pages/folder_invite_screen.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const String _code = 'ABCDEFGHJK';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockPublicProfileRepository extends Mock implements PublicProfileRepository {}

class _FakeSharedFoldersRepository implements SharedFoldersRepository {
  Result<FolderInvitePreview> preview = Result.success<FolderInvitePreview>(_openPreview());
  Result<String> joinResult = Result.success<String>('trip1');

  /// One entry per repository call.
  final List<String> calls = <String>[];

  @override
  Future<Result<FolderInvite>> createInvite(String folderId) async {
    calls.add('createInvite:$folderId');
    return Result.error(const SharedFolderFailure('unused'));
  }

  @override
  Future<Result<FolderInvitePreview>> previewInvite(String code) async {
    calls.add('previewInvite:$code');
    return preview;
  }

  @override
  Future<Result<String>> join(String code) async {
    calls.add('join:$code');
    return joinResult;
  }

  @override
  Future<Result<void>> removeMember(String folderId, String uid) async {
    calls.add('removeMember:$folderId:$uid');
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> leave(String folderId) async {
    calls.add('leave:$folderId');
    return Result.success<void>(null);
  }

  @override
  Future<Result<String?>> addedBy(String folderId, String itemKey) async {
    calls.add('addedBy:$folderId:$itemKey');
    return Result.success<String?>(null);
  }
}

FolderInviteOpen _openPreview({bool isMember = false}) => FolderInviteOpen(
  folderId: 'trip1',
  name: 'Trip',
  ownerId: 'owner',
  itemCount: 3,
  covers: const <String>[],
  memberCount: 2,
  isMember: isMember,
);

const PublicProfileEntity _ana = PublicProfileEntity(
  id: 'owner',
  name: 'Ana',
  email: '',
  username: 'ana',
  profilePhoto: '',
  bio: '',
  links: <String, String>{},
  coverPhoto: '',
);

void _signIn() {
  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'u1'
    ..loggedIn = true;
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSharedFoldersRepository repo;
  late _MockStackRouter router;

  setUpAll(() => registerFallbackValue(FolderRoute(folderId: 'x')));

  setUp(() {
    repo = _FakeSharedFoldersRepository();
    getIt.registerSingleton<SharedFoldersRepository>(repo);
    final _MockPublicProfileRepository profiles = _MockPublicProfileRepository();
    when(() => profiles.watchProfile('owner')).thenAnswer((_) => Stream.value(_ana));
    getIt.registerSingleton<PublicProfileRepository>(profiles);

    router = _MockStackRouter();
    when(() => router.stack).thenReturn(const <AutoRoutePage<dynamic>>[]);
    when(() => router.replace(any())).thenAnswer((_) => Future<void>.value());

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (MethodCall call) async => null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Widget host({double textScale = 1}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: kLightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const FolderInviteScreen(code: _code),
    ),
  );

  testWidgets('a signed-in non-member sees the folder preview and a Join folder button', (tester) async {
    _signIn();
    await tester.pumpWidget(host());
    await _settle(tester);

    expect(find.text('Join Trip'), findsOneWidget);
    expect(find.text('Ana invited you to add and remove wallpapers in this folder.'), findsOneWidget);
    expect(find.text('3 wallpapers · 2 people'), findsOneWidget);
    expect(find.text('Join folder'), findsOneWidget);
    expect(repo.calls, <String>['previewInvite:$_code']);
  });

  testWidgets('the invited-by line waits for the owner profile instead of showing a fallback name', (tester) async {
    _signIn();
    final StreamController<PublicProfileEntity?> owner = StreamController<PublicProfileEntity?>();
    final _MockPublicProfileRepository profiles = _MockPublicProfileRepository();
    when(() => profiles.watchProfile('owner')).thenAnswer((_) => owner.stream);
    await getIt.unregister<PublicProfileRepository>();
    getIt.registerSingleton<PublicProfileRepository>(profiles);
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();

    expect(find.text('Join Trip'), findsOneWidget);
    expect(find.textContaining('Prism user'), findsNothing);

    owner.add(_ana);
    await tester.pump();
    await tester.pump();
    expect(find.text('Ana invited you to add and remove wallpapers in this folder.'), findsOneWidget);
    await owner.close();
  });

  testWidgets('tapping Join folder joins the code once and opens the folder', (tester) async {
    _signIn();
    await tester.pumpWidget(host());
    await _settle(tester);

    await tester.tap(find.text('Join folder'));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(repo.calls.where((call) => call.startsWith('join:')), <String>['join:$_code']);
    verify(
      () => router.replace(any(that: isA<FolderRoute>().having((r) => r.args?.folderId, 'id', 'trip1'))),
    ).called(1);
    expect(find.text('This folder is full'), findsNothing);
  });

  testWidgets('a join refused as full switches the page to the full message', (tester) async {
    _signIn();
    repo.joinResult = Result.error(
      const SharedFolderFailure('full', refusal: FolderJoinRefusal.full, code: 'failed-precondition'),
    );
    await tester.pumpWidget(host());
    await _settle(tester);

    await tester.tap(find.text('Join folder'));
    await _settle(tester);

    expect(find.text('This folder is full'), findsOneWidget);
    expect(find.text('Ask the owner to remove someone, then open the link again.'), findsOneWidget);
    expect(find.text('Join folder'), findsNothing);
  });

  final List<(FolderJoinRefusal, String)> refusedTitles = <(FolderJoinRefusal, String)>[
    (FolderJoinRefusal.expired, 'This invite expired'),
    (FolderJoinRefusal.used, 'This invite was already used'),
    (FolderJoinRefusal.blocked, 'This invite is not available'),
    (FolderJoinRefusal.notFound, 'This invite is not available'),
    (FolderJoinRefusal.account, 'This invite is not available'),
  ];
  for (final (FolderJoinRefusal refusal, String title) in refusedTitles) {
    testWidgets('an invite refused as ${refusal.wireValue} shows "$title" and never the folder name', (tester) async {
      _signIn();
      repo.preview = Result.success<FolderInvitePreview>(FolderInviteRefused(refusal));
      await tester.pumpWidget(host());
      await _settle(tester);

      expect(find.text(title), findsOneWidget);
      expect(find.text('Trip'), findsNothing);
      expect(find.text('Join folder'), findsNothing);
    });
  }

  testWidgets('a preview that fails to load shows the error and Try again asks again', (tester) async {
    _signIn();
    repo.preview = Result.error(const NetworkFailure('offline'));
    await tester.pumpWidget(host());
    await _settle(tester);

    expect(find.text('Could not load this invite.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await _settle(tester);

    expect(repo.calls.where((call) => call == 'previewInvite:$_code'), hasLength(2));
  });

  testWidgets('a member sees that they are already in the folder and can open it', (tester) async {
    _signIn();
    repo.preview = Result.success<FolderInvitePreview>(_openPreview(isMember: true));
    await tester.pumpWidget(host());
    await _settle(tester);

    expect(find.text('You are already in this folder.'), findsOneWidget);
    expect(find.text('Open folder'), findsOneWidget);
    expect(find.text('Join folder'), findsNothing);
  });

  testWidgets('a guest sees Sign in to join instead of Join folder', (tester) async {
    await tester.pumpWidget(host());
    await _settle(tester);

    expect(find.text('Join Trip'), findsOneWidget);
    expect(find.text('Sign in to join'), findsOneWidget);
    expect(find.text('Join folder'), findsNothing);
  });

  testWidgets('the open invite lays out at 2x text on a 375 point wide screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _signIn();
    await tester.pumpWidget(host(textScale: 2));
    await _settle(tester);

    expect(find.text('Join folder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
