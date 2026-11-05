import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_member.dart';
import 'package:Prism/features/folders/views/widgets/folder_members_sheet.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFoldersBloc extends MockBloc<FoldersEvent, FoldersState> implements FoldersBloc {}

class _MockPublicProfileRepository extends Mock implements PublicProfileRepository {}

class _MockRouter extends Mock implements StackRouter {}

final DateTime _at = DateTime.utc(2026, 10);

FolderEntity _folder({int editorCount = 10}) => FolderEntity(
  id: 'f1',
  ownerId: 'owner',
  name: 'Places for our next adventure',
  createdAt: _at,
  updatedAt: _at,
  itemCount: 3,
  covers: const <String>[],
  editors: <FolderMember>[
    for (int i = 1; i <= editorCount; i++)
      FolderMember(uid: 'e$i', role: FolderRole.editor, addedBy: 'owner', addedAt: _at),
  ],
);

String _name(String uid) => uid == 'owner' ? 'Ananya Ramanathan' : 'Christopher Alexander Montgomery $uid';

PublicProfileEntity _profile(String uid, {String? name, String? username}) => PublicProfileEntity(
  id: uid,
  name: name ?? _name(uid),
  email: '',
  username: username ?? uid,
  profilePhoto: '',
  bio: '',
  links: const <String, String>{},
  coverPhoto: '',
);

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _expectTapTarget(WidgetTester tester, Finder finder, {required String label}) {
  final SemanticsNode node = tester.getSemantics(finder);
  expect(node.getSemanticsData().label, contains(label));
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  expect(node.rect.width, greaterThanOrEqualTo(44));
  expect(node.rect.height, greaterThanOrEqualTo(44));
  final Size size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(44));
  expect(size.height, greaterThanOrEqualTo(44));
}

void main() {
  late _MockPublicProfileRepository profiles;
  late _MockRouter router;

  setUpAll(() => registerFallbackValue(ProfileRoute(profileIdentifier: 'fallback')));

  setUp(() {
    profiles = _MockPublicProfileRepository();
    when(() => profiles.watchProfile(any())).thenAnswer((invocation) {
      final uid = invocation.positionalArguments.single as String;
      return Stream.value(_profile(uid));
    });
    getIt.registerSingleton<PublicProfileRepository>(profiles);
    router = _MockRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
  });

  tearDown(() => getIt.reset());

  Future<void> openSheet(
    WidgetTester tester, {
    String userId = 'owner',
    int editorCount = 10,
    double textScale = 2,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = _MockFoldersBloc();
    when(() => bloc.state).thenReturn(FoldersState.initial().copyWith(userId: userId));
    await tester.pumpWidget(
      MaterialApp(
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
          child: BlocProvider<FoldersBloc>.value(
            value: bloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => unawaited(showFolderMembersSheet(context, _folder(editorCount: editorCount))),
                  child: const Text('Open people'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open people'));
    await _settle(tester);
  }

  for (final double textScale in <double>[1, 2]) {
    testWidgets('all 11 real profiles remain readable and reachable at ${textScale}x on 375 points', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await openSheet(tester, textScale: textScale);

        expect(find.byType(PrismRow), findsNWidgets(11));
        expect(find.text('Ananya Ramanathan (you)'), findsOneWidget);
        expect(find.text('Owner'), findsOneWidget);
        expect(find.text('Can add and remove'), findsNWidgets(10));
        for (final String uid in <String>['owner', for (int i = 1; i <= 10; i++) 'e$i']) {
          final String title = uid == 'owner' ? '${_name(uid)} (you)' : _name(uid);
          final Finder row = find.widgetWithText(PrismRow, title);
          await tester.ensureVisible(row);
          await _settle(tester);
          expect(find.text(title).hitTestable(), findsOneWidget);
          _expectTapTarget(tester, find.descendant(of: row, matching: find.byType(InkWell)).first, label: title);
          if (uid != 'owner') {
            final Finder remove = find.descendant(of: row, matching: find.widgetWithText(FilledButton, 'Remove'));
            _expectTapTarget(tester, remove, label: 'Remove');
            if (textScale == 2) {
              expect(tester.getTopLeft(remove).dy, greaterThan(tester.getBottomLeft(find.text(title)).dy));
            }
          }
          expect(tester.takeException(), isNull, reason: 'Member $uid at ${textScale}x');
          verify(() => profiles.watchProfile(uid)).called(greaterThanOrEqualTo(1));
        }
        final invite = find.widgetWithText(FilledButton, 'Invite');
        expect(tester.widget<FilledButton>(invite).onPressed, isNull);
        expect(find.text('Invite').hitTestable(), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });
  }

  testWidgets('Remove has a real 44 point tap target and opens the named confirmation', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await openSheet(tester, editorCount: 1);
      final remove = find.widgetWithText(FilledButton, 'Remove');
      await tester.ensureVisible(remove);
      await _settle(tester);
      _expectTapTarget(tester, remove, label: 'Remove');
      final Rect target = tester.getRect(remove);
      await tester.tapAt(Offset(target.center.dx, target.bottom - 1));
      await _settle(tester);

      expect(find.text('Remove Christopher Alexander Montgomery e1?'), findsOneWidget);
      verifyNever(() => router.push(any()));
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('an editor can reach Leave folder with 11 people at 2x text', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await openSheet(tester, userId: 'e10');

      expect(find.text('Remove'), findsNothing);
      expect(find.text('Invite'), findsNothing);
      final leave = find.widgetWithText(FilledButton, 'Leave folder');
      _expectTapTarget(tester, leave, label: 'Leave folder');
      await tester.tap(leave);
      await _settle(tester);
      expect(find.text('Leave Places for our next adventure?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('a member row opens that public profile rather than the remove action', (tester) async {
    await openSheet(tester, editorCount: 1);
    await tester.ensureVisible(find.text(_name('e1')));
    await _settle(tester);
    await tester.tap(find.text(_name('e1')));
    await _settle(tester);

    final ProfileRoute route = verify(() => router.push(captureAny())).captured.single as ProfileRoute;
    expect(route.args!.profileIdentifier, 'e1');
    expect(find.text('People'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading profiles do not flash fallback names, and null or errors use the safe fallback', (tester) async {
    final owner = StreamController<PublicProfileEntity?>();
    final editor = StreamController<PublicProfileEntity?>();
    addTearDown(owner.close);
    addTearDown(editor.close);
    when(() => profiles.watchProfile('owner')).thenAnswer((_) => owner.stream);
    when(() => profiles.watchProfile('e1')).thenAnswer((_) => editor.stream);
    await openSheet(tester, editorCount: 1);

    expect(find.byType(PrismBone), findsNWidgets(4));
    expect(find.text('Prism user'), findsNothing);
    owner.add(_profile('owner', name: '   ', username: '  landscape_artist  '));
    editor.add(null);
    await _settle(tester);
    expect(find.text('@landscape_artist (you)'), findsOneWidget);
    expect(find.text('Prism user'), findsOneWidget);
    editor.addError(StateError('Profile unavailable'));
    await _settle(tester);
    expect(find.text('Prism user'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
