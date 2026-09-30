import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/admin_review/data/admin_review_repository.dart';
import 'package:Prism/features/admin_review/views/pages/admin_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdminReviewRepository extends AdminReviewRepository {
  _FakeAdminReviewRepository() : super();

  final FirestoreDocument wall = const FirestoreDocument('wall-1', <String, dynamic>{
    'by': 'Creator',
    'email': 'creator@example.com',
    'review': false,
  });
  int wallStreamCalls = 0;
  int approvals = 0;
  int rejections = 0;
  bool failFirstWallStream = false;
  Future<void> Function()? approveAction;
  Future<void> Function()? rejectAction;

  @override
  Stream<List<FirestoreDocument>> watchPendingWalls() {
    wallStreamCalls++;
    if (failFirstWallStream && wallStreamCalls == 1) {
      return Stream<List<FirestoreDocument>>.error(StateError('offline'));
    }
    return Stream<List<FirestoreDocument>>.value(<FirestoreDocument>[wall]);
  }

  @override
  Stream<List<FirestoreDocument>> watchPendingSetups() =>
      Stream<List<FirestoreDocument>>.value(const <FirestoreDocument>[]);

  @override
  Stream<List<FirestoreDocument>> watchOpenContentReports() =>
      Stream<List<FirestoreDocument>>.value(const <FirestoreDocument>[]);

  @override
  Future<void> approveWall(FirestoreDocument wall) async {
    approvals++;
    await approveAction?.call();
  }

  @override
  Future<void> rejectWall(FirestoreDocument wall, {required String reason}) async {
    rejections++;
    await rejectAction?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PrismUsersV2 originalUser;

  Future<void> pumpReviewScreen(WidgetTester tester, _FakeAdminReviewRepository repository) async {
    await tester.pumpWidget(MaterialApp(home: AdminReviewScreen(repository: repository)));
    await tester.pumpAndSettle();
  }

  setUp(() {
    originalUser = app_state.prismUser;
    final PrismUsersV2 adminUser = app_constants.createGuestPrismUser()
      ..email = app_constants.adminEmails.first
      ..loggedIn = true;
    app_state.prismUser = adminUser;
  });

  tearDown(() {
    app_state.prismUser = originalUser;
  });

  testWidgets('shows stream failure with a retry that reloads the pending list', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository()..failFirstWallStream = true;
    await pumpReviewScreen(tester, repository);

    expect(find.text('Could not load pending wallpapers.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(repository.wallStreamCalls, greaterThan(2));
    expect(find.text('ID: wall-1'), findsOneWidget);
  });

  testWidgets('approval disables repeat taps and offers an inline retry after failure', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    final Completer<void> pendingApproval = Completer<void>();
    repository.approveAction = () => pendingApproval.future;
    await pumpReviewScreen(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pump();
    expect(repository.approvals, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed, isNull);

    pendingApproval.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Approval failed. Check your connection, then try again.'), findsOneWidget);

    repository.approveAction = null;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(repository.approvals, 2);
  });

  testWidgets('rejection keeps the reason and dialog open after a save failure', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    final Completer<void> pendingRejection = Completer<void>();
    repository.rejectAction = () => pendingRejection.future;
    await pumpReviewScreen(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a reason before rejecting this item.'), findsOneWidget);
    expect(repository.rejections, 0);

    await tester.enterText(find.byType(TextField), 'Contains copied artwork');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pump();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel')).onPressed, isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    pendingRejection.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save this decision. Your reason is still here. Try again.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Contains copied artwork');
    expect(repository.rejections, 1);

    repository.rejectAction = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.rejections, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('rejection dialog remains usable with a short viewport and keyboard insets', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 640), viewInsets: EdgeInsets.only(bottom: 300)),
          child: AdminReviewScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Explain what needs to change'), findsOneWidget);
    expect(find.text('The creator will see this feedback.'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
