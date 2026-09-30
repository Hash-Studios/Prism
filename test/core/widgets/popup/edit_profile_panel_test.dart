import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/edit_profile_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/profile_user_fixture.dart';

void main() {
  setUp(() {
    app_state.prismUser = profileUser(
      id: 'me',
      username: 'creator_01',
      bio: 'Hello',
      profilePhoto: '',
      links: const <String, String>{'custom link': 'https://example.com'},
    )..name = 'Me Myself';
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    // A tall surface keeps every field on screen.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditProfilePanel())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save changes')).onPressed != null;

  testWidgets('shows the current profile in fields, with Save disabled until something changes', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Me Myself'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'creator_01'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Hello'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'https://example.com'), findsOneWidget);
    expect(find.text('Use 8 or more letters, numbers or underscores (_).'), findsOneWidget);
    expect(find.text('Change cover'), findsOneWidget);
    expect(find.byTooltip('Remove cover photo'), findsNothing);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('editing the name enables Save', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Me Myself'), 'Me Again');
    await tester.pump();

    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('a short username shows the rule as an error and keeps Save disabled', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.widgetWithText(TextField, 'creator_01'), 'short');
    await tester.pumpAndSettle();

    expect(find.text('Use 8 or more letters, numbers or underscores (_).'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('bio and link can be removed, and each asks first', (tester) async {
    await pumpPanel(tester);

    expect(find.byTooltip('Remove bio'), findsOneWidget);
    expect(find.byTooltip('Remove link'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove bio'));
    await tester.pumpAndSettle();

    expect(find.text('Remove bio?'), findsOneWidget);
    expect(find.text("This can't be undone."), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Hello'), findsOneWidget);
  });

  testWidgets('the link type opens a sheet that marks the current type', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.bySemanticsLabel('Link type, Custom link'));
    await tester.pumpAndSettle();

    expect(find.text('Link type'), findsOneWidget);
    expect(find.text('Github'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('Github'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Link type, Github'), findsOneWidget);
  });

  testWidgets('leaving with unsaved changes asks before discarding', (tester) async {
    await pumpPanel(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Me Myself'), 'Me Again');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsNothing);
  });

  testWidgets('leaving without changes does not ask', (tester) async {
    await pumpPanel(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit profile'), findsNothing);
  });
}
