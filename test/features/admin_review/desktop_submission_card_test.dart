import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/widgets/desktop_submission_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_desktop_submissions.dart';

Widget _app(Widget home, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: home)),
);

DesktopSubmissionCard _card({bool replaces = false}) => DesktopSubmissionCard(
  submission: desktopSubmission(replaces: replaces),
  onApprove: () async {},
  onReject: () async {},
);

void main() {
  testWidgets('labels the phone and desktop previews for screen readers', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_card()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Phone wallpaper'), findsOneWidget);
    expect(find.bySemanticsLabel('Desktop version, 2560 × 1600'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows the upload size and the replaces line only when the wall already has a desktop version', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_card()));
    await tester.pumpAndSettle();

    expect(find.text('2560 × 1600, 16:10'), findsOneWidget);
    expect(find.text('Replaces the current desktop version'), findsNothing);

    await tester.pumpWidget(_app(_card(replaces: true)));
    await tester.pumpAndSettle();

    expect(find.text('Replaces the current desktop version'), findsOneWidget);
  });

  testWidgets('stacks the previews at 2x text without exceptions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(SizedBox(width: 320, child: _card()), textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(PrismButton, 'Approve'), findsOneWidget);
  });
}
