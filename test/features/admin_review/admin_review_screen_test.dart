import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/pages/admin_review_screen.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<String> reviewedReports = <String>[];
  bool failFirstWallStream = false;
  Stream<List<FirestoreDocument>>? reportsStream;
  Stream<List<FirestoreDocument>>? wallsStream;
  List<FirestoreDocument>? wallsList;
  List<FirestoreDocument>? reportsList;
  Future<void> Function()? approveAction;
  Future<void> Function()? rejectAction;

  @override
  Stream<List<FirestoreDocument>> watchPendingWalls() {
    wallStreamCalls++;
    if (wallsStream != null) return wallsStream!;
    if (wallsList != null) return Stream<List<FirestoreDocument>>.value(wallsList!);
    if (failFirstWallStream && wallStreamCalls == 1) {
      return Stream<List<FirestoreDocument>>.error(StateError('offline'));
    }
    return Stream<List<FirestoreDocument>>.value(<FirestoreDocument>[wall]);
  }

  @override
  Stream<List<FirestoreDocument>> watchOpenContentReports() =>
      reportsStream ?? Stream<List<FirestoreDocument>>.value(reportsList ?? const <FirestoreDocument>[]);

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

  @override
  Future<void> markContentReportReviewed(String reportDocId, {String? resolution}) async {
    reviewedReports.add(reportDocId);
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

  Widget app(Widget home, {MediaQueryData? media}) => MaterialApp(
    builder: (BuildContext context, Widget? child) =>
        MediaQuery(data: (media ?? MediaQuery.of(context)).copyWith(disableAnimations: true), child: child!),
    home: home,
  );

  Future<void> pumpReviewScreen(WidgetTester tester, _FakeAdminReviewRepository repository) async {
    await tester.pumpWidget(app(AdminReviewScreen(repository: repository)));
    await tester.pumpAndSettle();
  }

  FilledButton filledIn(WidgetTester tester, Finder scope) =>
      tester.widget<FilledButton>(find.descendant(of: scope, matching: find.byType(FilledButton)));

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

  testWidgets('shows a skeleton while the pending list loads', (WidgetTester tester) async {
    final StreamController<List<FirestoreDocument>> walls = StreamController<List<FirestoreDocument>>.broadcast();
    addTearDown(walls.close);
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository()..wallsStream = walls.stream;
    await tester.pumpWidget(app(AdminReviewScreen(repository: repository)));
    await tester.pump();

    expect(find.byType(PrismSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Walls'), findsOneWidget);
    expect(find.text('Admin moderation'), findsOneWidget);
  });

  testWidgets('shows Glint and a message when nothing is waiting', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository()..wallsList = const <FirestoreDocument>[];
    await pumpReviewScreen(tester, repository);

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('Nothing to review'), findsOneWidget);
    expect(find.text('Walls (0)'), findsOneWidget);
  });

  testWidgets('shows stream failure with a retry that reloads the pending list', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository()..failFirstWallStream = true;
    await pumpReviewScreen(tester, repository);

    expect(find.text('Could not load pending wallpapers.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.wallStreamCalls, greaterThan(2));
    expect(find.text('wall-1'), findsOneWidget);
  });

  testWidgets('pending wallpaper card shows its creator details and both actions', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    await pumpReviewScreen(tester, repository);

    expect(find.text('wall-1'), findsOneWidget);
    expect(find.text('Creator'), findsOneWidget);
    expect(find.text('creator@example.com'), findsOneWidget);
    expect(find.bySemanticsLabel('By: Creator'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(ModerationDangerButton, 'Reject'), findsOneWidget);
    expect(find.byTooltip('View full wallpaper'), findsOneWidget);
    expect(find.byTooltip('Swipe review'), findsOneWidget);
    semantics.dispose();
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
    await tester.pumpWidget(app(AdminReviewScreen(repository: repository)));
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
    expect(firestore.requestedWallIds, containsAll(<String>['wall-a', 'wall-b']));

    void expectReportPreview(String reason, String wallId) {
      final Finder report = find.ancestor(of: find.text(wallId), matching: find.byType(PrismCard));
      expect(report, findsOneWidget, reason: 'report with reason $reason should target $wallId');
      expect(find.descendant(of: report, matching: find.text(reason)), findsOneWidget);
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
    expect(find.text('Keep wallpaper'), findsNWidgets(2));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Send notification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a report on something other than a wall offers Mark reviewed', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository()
      ..reportsList = const <FirestoreDocument>[
        FirestoreDocument('report-u', <String, dynamic>{
          'contentType': 'user',
          'reason': 'Spam',
          'targetFirestoreDocId': 'user-1',
          'reporterUid': 'reporter-1',
        }),
      ];
    await tester.pumpWidget(app(AdminReviewScreen(repository: repository)));
    await tester.drag(find.byType(TabBarView), const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(find.text('Spam'), findsOneWidget);
    expect(find.text('user report'), findsOneWidget);
    await tester.tap(find.text('Mark reviewed'));
    await tester.pumpAndSettle();
    expect(repository.reviewedReports, <String>['report-u']);
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
    await tester.pumpWidget(app(AdminReviewScreen(repository: repository)));
    await tester.pump();
    walls.add(const <FirestoreDocument>[
      FirestoreDocument('wall-a', <String, dynamic>{'review': false}),
      FirestoreDocument('wall-b', <String, dynamic>{'review': false}),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('wall-b'), findsOneWidget);
    final Finder wallBCard = find.ancestor(of: find.text('wall-b'), matching: find.byType(PrismCard));
    await tester.tap(find.descendant(of: wallBCard, matching: find.text('Approve')));
    await tester.pump();
    expect(repository.approvals, 1);

    walls.add(const <FirestoreDocument>[
      FirestoreDocument('wall-b', <String, dynamic>{'review': false}),
    ]);
    await tester.pump();
    expect(wallBCard, findsOneWidget);
    expect(find.descendant(of: wallBCard, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    final Finder approve = find.descendant(of: wallBCard, matching: find.byType(PrismButton));
    expect(tester.widget<PrismButton>(approve).loading, isTrue);
    await tester.tap(approve, warnIfMissed: false);
    await tester.pump();
    expect(repository.approvals, 1);

    pendingApproval.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('approval blocks repeat taps and offers an inline retry after failure', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    final Completer<void> pendingApproval = Completer<void>();
    repository.approveAction = () => pendingApproval.future;
    await pumpReviewScreen(tester, repository);

    await tester.tap(find.text('Approve'));
    await tester.pump();
    expect(repository.approvals, 1);
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).loading, isTrue);
    await tester.tap(find.byType(PrismButton), warnIfMissed: false);
    await tester.pump();
    expect(repository.approvals, 1);

    pendingApproval.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Approval failed. Check your connection, then try again.'), findsOneWidget);

    repository.approveAction = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.approvals, 2);
  });

  testWidgets('successful approval stays disabled until the stream removes its card', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    await pumpReviewScreen(tester, repository);

    final VoidCallback? staleApprove = tester
        .widget<PrismButton>(find.widgetWithText(PrismButton, 'Approve'))
        .onPressed;
    staleApprove!();
    await tester.pumpAndSettle();
    expect(repository.approvals, 1);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Approved')).onPressed, isNull);
    expect(filledIn(tester, find.widgetWithText(ModerationDangerButton, 'Reject')).onPressed, isNull);

    staleApprove();
    await tester.pumpAndSettle();
    expect(repository.approvals, 1);
  });

  testWidgets('rejection keeps the reason and sheet open after a save failure', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    final Completer<void> pendingRejection = Completer<void>();
    repository.rejectAction = () => pendingRejection.future;
    await pumpReviewScreen(tester, repository);

    await tester.tap(find.widgetWithText(ModerationDangerButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(find.byType(PrismSheetBody), findsOneWidget);
    expect(find.text('Low quality'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a reason before rejecting this item.'), findsOneWidget);
    expect(repository.rejections, 0);

    await tester.enterText(find.byType(TextField), 'Contains copied artwork');
    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pump();
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Cancel')).onPressed, isNull);
    await tester.tap(find.widgetWithText(PrismButton, 'Cancel'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(PrismSheetBody), findsOneWidget);

    pendingRejection.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save this decision. Your reason is still here. Try again.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Contains copied artwork');
    expect(repository.rejections, 1);

    repository.rejectAction = null;
    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.rejections, 2);
    expect(find.byType(PrismSheetBody), findsNothing);
  });

  testWidgets('a quick reason fills the reason field', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    await pumpReviewScreen(tester, repository);

    await tester.tap(find.widgetWithText(ModerationDangerButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low quality'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Low quality');
    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pumpAndSettle();
    expect(repository.rejections, 1);
  });

  testWidgets('rejection sheet remains usable with a short viewport and keyboard insets', (WidgetTester tester) async {
    final _FakeAdminReviewRepository repository = _FakeAdminReviewRepository();
    tester.view.physicalSize = const Size(700, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        AdminReviewScreen(repository: repository),
        media: const MediaQueryData(size: Size(700, 640), viewInsets: EdgeInsets.only(bottom: 300)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ModerationDangerButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Explain what needs to change'), findsOneWidget);
    expect(find.text('The creator will see this feedback.'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('notifications tab', () {
    Future<void> openNotifications(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpReviewScreen(tester, _FakeAdminReviewRepository());
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
    }

    testWidgets('requires a title and a body before sending', (WidgetTester tester) async {
      await openNotifications(tester);

      await tester.tap(find.text('Send notification'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
      expect(find.text('Body is required'), findsOneWidget);
      expect(firestore.writes, isEmpty);
    });

    testWidgets('asks for a valid email when the audience is one user', (WidgetTester tester) async {
      await openNotifications(tester);

      await tester.enterText(find.widgetWithText(TextField, '').first, 'Hello');
      await tester.tap(find.text('Specific user (email)'));
      await tester.pumpAndSettle();
      expect(find.text('User email'), findsOneWidget);
      await tester.tap(find.text('Send notification'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('asks before sending to a whole group and sends nothing when cancelled', (WidgetTester tester) async {
      await openNotifications(tester);

      final List<Finder> fields = <Finder>[find.byType(TextField).at(0), find.byType(TextField).at(1)];
      await tester.enterText(fields[0], 'New wallpapers');
      await tester.enterText(fields[1], 'Fresh drops this week');
      await tester.pump();
      expect(find.text('Preview'), findsOneWidget);

      await tester.tap(find.text('Send notification'));
      await tester.pumpAndSettle();
      expect(find.text('Send to all users?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(firestore.writes, isEmpty);
    });
  });
}
