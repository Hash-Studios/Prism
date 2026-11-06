import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/features/desktop_submission/views/widgets/desktop_version_action.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements DesktopSubmissionRepository {
  _FakeRepo(this.pending);

  final Stream<bool> pending;

  @override
  Stream<bool> watchPendingForWall({required String wallDocId, required String uid}) => pending;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('desktopMenuState', () {
    test('pending wins over the other flags', () {
      expect(desktopMenuState(hasDesktop: false, pending: true), DesktopMenuState.inReview);
      expect(desktopMenuState(hasDesktop: true, pending: true), DesktopMenuState.inReview);
    });

    test('an existing desktop version means replace', () {
      expect(desktopMenuState(hasDesktop: true, pending: false), DesktopMenuState.replace);
    });

    test('no desktop version and nothing pending means add', () {
      expect(desktopMenuState(hasDesktop: false, pending: false), DesktopMenuState.add);
    });
  });

  Future<void> pumpAction(
    WidgetTester tester, {
    required bool hasDesktop,
    required Stream<bool> pending,
    required void Function(bool replace) onOpen,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DesktopVersionAction(
            wallDocId: 'wall_1',
            uid: 'uid_1',
            hasDesktop: hasDesktop,
            onOpen: onOpen,
            repository: _FakeRepo(pending),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows add when the wall has no desktop version', (tester) async {
    await pumpAction(tester, hasDesktop: false, pending: Stream<bool>.value(false), onOpen: (_) {});

    expect(find.text('Add a desktop version'), findsOneWidget);
    expect(find.text('Replace desktop version'), findsNothing);
  });

  testWidgets('shows replace when the wall already has a desktop version', (tester) async {
    await pumpAction(tester, hasDesktop: true, pending: Stream<bool>.value(false), onOpen: (_) {});

    expect(find.text('Replace desktop version'), findsOneWidget);
    expect(find.text('Add a desktop version'), findsNothing);
  });

  testWidgets('shows a disabled in-review button while a version is pending', (tester) async {
    await pumpAction(tester, hasDesktop: false, pending: Stream<bool>.value(true), onOpen: (_) {});

    expect(find.text('Desktop version in review'), findsOneWidget);
    final PrismButton button = tester.widget<PrismButton>(
      find.widgetWithText(PrismButton, 'Desktop version in review'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a failed pending watch leaves the add button enabled', (tester) async {
    await pumpAction(tester, hasDesktop: false, pending: Stream<bool>.error(Exception('watch failed')), onOpen: (_) {});

    expect(find.text('Add a desktop version'), findsOneWidget);
    final PrismButton button = tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Add a desktop version'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('tapping add opens the upload with replace false', (tester) async {
    final List<bool> opened = <bool>[];
    await pumpAction(tester, hasDesktop: false, pending: Stream<bool>.value(false), onOpen: opened.add);

    await tester.tap(find.text('Add a desktop version'));
    await tester.pump();

    expect(opened, <bool>[false]);
  });

  testWidgets('tapping replace opens the upload with replace true', (tester) async {
    final List<bool> opened = <bool>[];
    await pumpAction(tester, hasDesktop: true, pending: Stream<bool>.value(false), onOpen: opened.add);

    await tester.tap(find.text('Replace desktop version'));
    await tester.pump();

    expect(opened, <bool>[true]);
  });
}
