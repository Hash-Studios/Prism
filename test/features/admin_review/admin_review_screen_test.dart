import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/pages/admin_review_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _FakeAdminReviewRepository extends AdminModerationRepository {
  _FakeAdminReviewRepository() : super(FakeFirestoreClient());

  final FirestoreDocument wall = const FirestoreDocument('wall-1', <String, dynamic>{
    'by': 'Creator',
    'email': 'creator@example.com',
    'review': false,
  });
  int wallStreamCalls = 0;
  int approvals = 0;
  int rejections = 0;
  bool failFirstWallStream = false;
  Stream<List<FirestoreDocument>>? reportsStream;
  Stream<List<FirestoreDocument>>? wallsStream;
  Future<void> Function()? approveAction;
  Future<void> Function()? rejectAction;

  @override
  Stream<List<FirestoreDocument>> watchPendingWalls() {
    wallStreamCalls++;
    if (wallsStream != null) return wallsStream!;
    if (failFirstWallStream && wallStreamCalls == 1) {
      return Stream<List<FirestoreDocument>>.error(StateError('offline'));
    }
    return Stream<List<FirestoreDocument>>.value(<FirestoreDocument>[wall]);
  }

  @override
  Stream<List<FirestoreDocument>> watchOpenContentReports() =>
      reportsStream ?? Stream<List<FirestoreDocument>>.value(const <FirestoreDocument>[]);

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

class _RecordingFirestoreClient extends FakeFirestoreClient {
  final List<String> requestedWallIds = <String>[];

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    requestedWallIds.add(id);
    return map(<String, dynamic>{'wallpaper_thumb': 'https://example.com/$id.png'}, id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PrismUsersV2 originalUser;
  late _RecordingFirestoreClient firestore;

  Future<void> pumpReviewScreen(WidgetTester tester, _FakeAdminReviewRepository repository) async {
    await tester.pumpWidget(MaterialApp(home: AdminReviewScreen(repository: repository)));
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    firestore = _RecordingFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
  });

  tearDownAll(() => getIt.unregister<FirestoreClient>());

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

  testWidgets('pending wallpaper card shows its creator details', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    await pumpReviewScreen(tester, repository);

    expect(find.text('ID: wall-1'), findsOneWidget);
    expect(find.text('By: Creator'), findsOneWidget);
    expect(find.text('Email: creator@example.com'), findsOneWidget);
  });

  testWidgets('wall report previews stay with their report after the stream reorders rows', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final StreamController<List<FirestoreDocument>> reports = StreamController<List<FirestoreDocument>>.broadcast();
    addTearDown(reports.close);
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository()..reportsStream = reports.stream;
    await tester.pumpWidget(MaterialApp(home: AdminReviewScreen(repository: repository)));
    await tester.drag(find.byType(TabBarView), const Offset(-800, 0));
    await tester.pump(const Duration(milliseconds: 600));
    reports.add(const <FirestoreDocument>[
      FirestoreDocument('report-a', <String, dynamic>{
        'contentType': 'wall',
        'reason': 'A',
        'targetFirestoreDocId': 'wall-a',
      }),
      FirestoreDocument('report-b', <String, dynamic>{
        'contentType': 'wall',
        'reason': 'B',
        'targetFirestoreDocId': 'wall-b',
      }),
    ]);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Walls (1)'), findsOneWidget);
    expect(find.text('Reports (2)'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('wall — A'), findsOneWidget);
    expect(find.text('wall — B'), findsOneWidget);
    expect(firestore.requestedWallIds, containsAll(<String>['wall-a', 'wall-b']));

    void expectReportPreview(String reason, String wallId) {
      final Finder report = find.ancestor(of: find.textContaining('Target: $wallId'), matching: find.byType(Card));
      expect(report, findsOneWidget, reason: 'report with reason $reason should target $wallId');
      expect(find.descendant(of: report, matching: find.text('wall — $reason')), findsOneWidget);
      final Finder preview = find.descendant(of: report, matching: find.byType(CachedNetworkImage));
      expect(preview, findsOneWidget);
      expect(tester.widget<CachedNetworkImage>(preview).imageUrl, 'https://example.com/$wallId.png');
    }

    expectReportPreview('A', 'wall-a');
    expectReportPreview('B', 'wall-b');

    reports.add(const <FirestoreDocument>[
      FirestoreDocument('report-b', <String, dynamic>{
        'contentType': 'wall',
        'reason': 'B',
        'targetFirestoreDocId': 'wall-b',
      }),
      FirestoreDocument('report-a', <String, dynamic>{
        'contentType': 'wall',
        'reason': 'A',
        'targetFirestoreDocId': 'wall-a',
      }),
    ]);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expectReportPreview('A', 'wall-a');
    expectReportPreview('B', 'wall-b');
    expect(firestore.requestedWallIds, containsAll(<String>['wall-a', 'wall-b']));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Compose notification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approval state stays with the same wall after an earlier row is removed', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final StreamController<List<FirestoreDocument>> walls = StreamController<List<FirestoreDocument>>.broadcast();
    addTearDown(walls.close);
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository()..wallsStream = walls.stream;
    final Completer<void> pendingApproval = Completer<void>();
    repository.approveAction = () => pendingApproval.future;
    await tester.pumpWidget(MaterialApp(home: AdminReviewScreen(repository: repository)));
    await tester.pump();
    walls.add(const <FirestoreDocument>[
      FirestoreDocument('wall-a', <String, dynamic>{'review': false}),
      FirestoreDocument('wall-b', <String, dynamic>{'review': false}),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('ID: wall-b'), findsOneWidget);
    final Finder wallBCard = find.ancestor(of: find.text('ID: wall-b'), matching: find.byType(Card));
    final Finder wallBApprove = find.descendant(of: wallBCard, matching: find.widgetWithText(FilledButton, 'Approve'));
    await tester.tap(wallBApprove);
    await tester.pump();
    expect(repository.approvals, 1);

    walls.add(const <FirestoreDocument>[
      FirestoreDocument('wall-b', <String, dynamic>{'review': false}),
    ]);
    await tester.pump();
    expect(wallBCard, findsOneWidget);
    expect(find.descendant(of: wallBCard, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    final Finder wallBButton = find.descendant(of: wallBCard, matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(wallBButton).onPressed, isNull);
    await tester.tap(wallBButton, warnIfMissed: false);
    await tester.pump();
    expect(repository.approvals, 1);

    pendingApproval.complete();
    await tester.pumpAndSettle();
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

  testWidgets('successful approval stays disabled until the stream removes its card', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    await pumpReviewScreen(tester, repository);

    final VoidCallback? staleApprove = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'))
        .onPressed;
    staleApprove!();
    await tester.pumpAndSettle();
    expect(repository.approvals, 1);
    expect(find.widgetWithText(FilledButton, 'Approved'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Reject')).onPressed, isNull);

    staleApprove();
    await tester.pumpAndSettle();
    expect(repository.approvals, 1);
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
