import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/edit_profile_panel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/profile_user_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late FakeFirestoreClient firestore;

  setUp(() async {
    await getIt.reset();
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
    app_state.prismUser = profileUser(
      id: 'me',
      username: 'creator_01',
      bio: 'Hello',
      profilePhoto: '',
      links: const <String, String>{'custom link': 'https://example.com'},
    )..name = 'Me Myself';
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    await getIt.reset();
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    // A tall surface keeps every field on screen.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
    expect(find.text('Use 3 or more letters, numbers or underscores (_).'), findsOneWidget);
    expect(find.text('Edit cover'), findsOneWidget);
    expect(find.byTooltip('Remove cover photo'), findsNothing);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('change cover photo has a hit target of at least 44 pixels', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpPanel(tester);

      expect(tester.getRect(find.bySemanticsLabel('Change cover photo')).height, greaterThanOrEqualTo(44));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('editing the name enables Save', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Me Myself'), 'Me Again');
    await tester.pump();

    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('dirty name still asks before leaving when username is invalid', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Me Myself'), 'Me Again');
    await tester.enterText(find.widgetWithText(TextField, 'creator_01'), 'ab');
    await tester.pumpAndSettle();

    expect(saveEnabled(tester), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  group('username', () {
    Finder usernameField() => find.widgetWithText(TextField, 'creator_01');

    testWidgets('two characters show an inline error and cannot be saved', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'ab');
      await tester.pump();

      expect(find.text('Use at least 3 characters.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('three characters are accepted and saved once they are free', (tester) async {
      firestore.onQuery = (_) => const <FakeDocRow>[];
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'abc');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Use at least 3 characters.'), findsNothing);
      expect(find.text('That username is taken.'), findsNothing);
      expect(saveEnabled(tester), isTrue);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(firestore.writes.single.data, <String, dynamic>{'username': 'abc'});
    });

    testWidgets('a name another user holds shows an inline error', (tester) async {
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'someone-else', data: <String, dynamic>{})];
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'taken_name');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('That username is taken.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('spaces and symbols show an inline error', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'bad name!');
      await tester.pump();

      expect(find.text('Use letters, numbers and underscores only.'), findsOneWidget);
    });
  });

  group('links', () {
    Finder linkField() => find.widgetWithText(TextField, 'https://example.com');

    Future<void> selectCoffee(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Link type, Custom link'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buy Me a Coffee'));
      await tester.tap(find.text('Buy Me a Coffee'));
      await tester.pumpAndSettle();
    }

    for (final String host in <String>['buymeacoffee.com', 'buymeacoff.ee']) {
      testWidgets('a $host link enables Save and is persisted under the stable coffee key', (tester) async {
        await pumpPanel(tester);
        await selectCoffee(tester);

        await tester.enterText(find.widgetWithText(TextField, ''), 'https://$host/prism');
        await tester.pump();

        expect(find.text('Enter a valid Buy Me a Coffee link.'), findsNothing);
        expect(saveEnabled(tester), isTrue);
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        expect((firestore.writes.single.data!['links'] as Map)['buymeacoffee'], 'https://$host/prism');
      });
    }

    testWidgets('a coffee domain in an unrelated URL shows an error and blocks Save', (tester) async {
      await pumpPanel(tester);
      await selectCoffee(tester);

      await tester.enterText(find.widgetWithText(TextField, ''), 'https://example.com/buymeacoff.ee');
      await tester.pump();

      expect(find.text('Enter a valid Buy Me a Coffee link.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      expect(firestore.writes, isEmpty);
    });

    testWidgets('a link with an unsafe scheme shows an inline error and blocks saving', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(linkField(), 'javascript:alert(1)');
      await tester.pump();

      expect(find.text('Enter a valid link.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('an https link clears the error and is saved as typed', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(linkField(), 'javascript:alert(1)');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'javascript:alert(1)'), 'https://example.com/me');
      await tester.pump();

      expect(find.text('Enter a valid link.'), findsNothing);
      expect(saveEnabled(tester), isTrue);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect((firestore.writes.single.data!['links'] as Map)['custom link'], 'https://example.com/me');
    });
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
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Link type, GitHub'), findsOneWidget);
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
