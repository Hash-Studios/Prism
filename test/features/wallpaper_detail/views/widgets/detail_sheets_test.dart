import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/content_reports/content_report_repository.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_analytics.dart';

class _FakeReports implements ContentReportRepository {
  _FakeReports(this.result);

  final Result<void> result;
  final List<String> reasons = <String>[];
  final List<String> details = <String>[];

  @override
  Future<Result<void>> submitReport({
    required String contentType,
    required String targetFirestoreDocId,
    required String reason,
    String details = '',
    String appVersion = '',
  }) async {
    reasons.add(reason);
    this.details.add(details);
    return result;
  }
}

Widget _host(Widget Function(BuildContext) sheet) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => showPrismSheet<void>(context: context, isScrollControlled: true, builder: sheet),
        child: const Text('open'),
      ),
    ),
  ),
);

/// A focused text field blinks its caret forever, so pump a fixed time instead of settling.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (_) async => <String, Object?>{
        'appName': 'Prism',
        'packageName': 'com.hash.prism',
        'version': '1.0.0',
        'buildNumber': '1',
        'buildSignature': '',
      },
    );
  });

  group('SetOptionsPanel', () {
    testWidgets('lists home, lock and both as rows and reports the tapped one', (tester) async {
      final List<String> taps = <String>[];
      await tester.pumpWidget(
        _host(
          (_) => SetOptionsPanel(
            onTap1: () => taps.add('home'),
            onTap2: () => taps.add('lock'),
            onTap3: () => taps.add('both'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Set wallpaper'), findsOneWidget);
      expect(find.byType(PrismRow), findsNWidgets(3));
      await tester.tap(find.text('Home screen'));
      await tester.tap(find.text('Lock screen'));
      await tester.tap(find.text('Both'));

      expect(taps, <String>['home', 'lock', 'both']);
    });
  });

  group('ContentReportSheetBody', () {
    late FakeAppAnalytics recorded;

    setUp(() {
      recorded = FakeAppAnalytics();
      AnalyticsRuntime.instance = recorded;
    });

    tearDown(() async {
      AnalyticsRuntime.reset();
      await getIt.reset();
    });

    Future<_FakeReports> openSheet(WidgetTester tester, Result<void> result) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _FakeReports reports = _FakeReports(result);
      getIt.registerSingleton<ContentReportRepository>(reports);
      await tester.pumpWidget(
        _host(
          (_) => const ContentReportSheetBody(contentType: 'wall', targetFirestoreDocId: 'doc-1', subtitle: 'Z3ZF'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return reports;
    }

    testWidgets('shows the reasons as rows and a Send report button', (tester) async {
      await openSheet(tester, Result.success(null));

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Why are you reporting this wallpaper (Z3ZF)?'), findsOneWidget);
      for (final (String _, String label) in kContentReportReasons) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.widgetWithText(FilledButton, 'Send report'), findsOneWidget);
      expect(find.byType(RadioListTile<String>), findsNothing);
    });

    testWidgets('sends the chosen reason and details, then closes', (tester) async {
      final _FakeReports reports = await openSheet(tester, Result.success(null));

      await tester.tap(find.text('Spam or misleading'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Looks like an ad');
      await tester.tap(find.text('Send report'));
      await _settle(tester);

      expect(reports.reasons, <String>['spam']);
      expect(reports.details, <String>['Looks like an ad']);
      expect(recorded.events.whereType<ContentReportSubmitEvent>().single.result, BinaryResultValue.success);
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('does not send without a reason', (tester) async {
      final _FakeReports reports = await openSheet(tester, Result.success(null));

      await tester.tap(find.text('Send report'));
      await tester.pump();

      expect(reports.reasons, isEmpty);
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('keeps the sheet open when the send fails', (tester) async {
      final _FakeReports reports = await openSheet(tester, Result.error(const ServerFailure('Try later')));

      await tester.tap(find.text('Other'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await _settle(tester);

      expect(reports.reasons, <String>['other']);
      expect(find.text('Report'), findsOneWidget);
      expect(recorded.events.whereType<ContentReportSubmitEvent>().single.result, BinaryResultValue.failure);
    });
  });
}
