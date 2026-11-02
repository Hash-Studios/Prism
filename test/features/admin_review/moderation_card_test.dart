import 'dart:async';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: home)),
);

ModerationCard _card({Future<void> Function()? onApproveAndPick, Future<void> Function()? onApprove}) => ModerationCard(
  previewUrl: '',
  fullUrl: '',
  facts: const <(String, String)>[('By', 'Creator')],
  onApprove: onApprove ?? () async {},
  onApproveAndPick: onApproveAndPick,
  onReject: () async {},
);

void main() {
  testWidgets('shows Approve and pick only when a pick callback is given', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_card()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PrismButton, 'Approve and pick'), findsNothing);
    expect(find.widgetWithText(PrismButton, 'Approve'), findsOneWidget);

    await tester.pumpWidget(_app(_card(onApproveAndPick: () async {})));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PrismButton, 'Approve and pick'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Approve'), findsOneWidget);
  });

  testWidgets('Approve and pick runs its callback once, even on a double tap', (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    int calls = 0;
    await tester.pumpWidget(
      _app(
        _card(
          onApproveAndPick: () {
            calls++;
            return gate.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(PrismButton, 'Approve and pick'));
    await tester.tap(find.widgetWithText(PrismButton, 'Approve and pick'));
    await tester.pump();

    expect(calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('pick and approve buttons render at 2x text without exceptions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        SizedBox(width: 320, child: _card(onApproveAndPick: () async {})),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PrismButton, 'Approve and pick'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Approve'), findsOneWidget);
    expect(find.byType(ModerationDangerButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
