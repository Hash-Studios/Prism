import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/widgets/desktop_submission_queue.dart';
import 'package:Prism/features/desktop_submission/desktop_submission.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import 'fake_desktop_submissions.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  home: Scaffold(body: home),
);

void main() {
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(AnalyticsRuntime.reset);

  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);
  }

  void mockToasts(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
  }

  testWidgets('shows the empty state when no desktop version is waiting', (WidgetTester tester) async {
    await tester.pumpWidget(_app(DesktopSubmissionQueue(repository: FakeDesktopSubmissionRepository())));
    await tester.pumpAndSettle();

    expect(find.text('No desktop versions to review'), findsOneWidget);
  });

  testWidgets('Approve sends approve to the repository and tracks it', (WidgetTester tester) async {
    mockToasts(tester);
    useTallView(tester);
    final FakeDesktopSubmissionRepository repository = FakeDesktopSubmissionRepository(
      submissions: <DesktopSubmission>[desktopSubmission()],
    );
    await tester.pumpWidget(_app(DesktopSubmissionQueue(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(PrismButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(repository.reviews.single.submissionId, 'sub-1');
    expect(repository.reviews.single.approve, isTrue);
    expect(analytics.events.whereType<DesktopUploadApprovedEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Reject with the Blurry reason sends the reason and its code', (WidgetTester tester) async {
    mockToasts(tester);
    useTallView(tester);
    final FakeDesktopSubmissionRepository repository = FakeDesktopSubmissionRepository(
      submissions: <DesktopSubmission>[desktopSubmission()],
    );
    await tester.pumpWidget(_app(DesktopSubmissionQueue(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blurry'));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrismButton, 'Reject desktop version'));
    await tester.pumpAndSettle();

    final review = repository.reviews.single;
    expect(review.approve, isFalse);
    expect(review.reason, isNotEmpty);
    expect(review.reasonCode, 'blurry');
    await tester.pump(const Duration(seconds: 2));
  });
}
