import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/edit_profile_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late FakeFirestoreClient firestore;

  setUp(() async {
    await getIt.reset();
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'me'
      ..loggedIn = true
      ..username = 'old_name'
      ..bio = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: EditProfilePanel()));
    await tester.pumpAndSettle();
  }

  Finder usernameField() => find.widgetWithText(TextField, 'Username');

  bool updateEnabled(WidgetTester tester) {
    final button = find.ancestor(of: find.text('Update'), matching: find.byType(InkWell));
    return tester.widget<InkWell>(button.first).onTap != null;
  }

  group('username', () {
    testWidgets('two characters show an inline error and cannot be saved', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'ab');
      await tester.pump();

      expect(find.text('Use at least 3 characters.'), findsOneWidget);
      expect(updateEnabled(tester), isFalse);
    });

    testWidgets('three characters are accepted and saved once they are free', (tester) async {
      firestore.onQuery = (_) => const <FakeDocRow>[];
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'abc');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Use at least 3 characters.'), findsNothing);
      expect(find.text('That username is taken.'), findsNothing);
      expect(updateEnabled(tester), isTrue);

      await tester.tap(find.text('Update'));
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
      expect(updateEnabled(tester), isFalse);
    });

    testWidgets('spaces and symbols show an inline error', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'bad name!');
      await tester.pump();

      expect(find.text('Use letters, numbers and underscores only.'), findsOneWidget);
    });
  });

  group('links', () {
    Finder linkField() => find.widgetWithText(TextField, 'Custom link');

    testWidgets('a link with an unsafe scheme shows an inline error and blocks saving', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(linkField(), 'javascript:alert(1)');
      await tester.pump();

      expect(find.text('Enter a valid link.'), findsOneWidget);
      expect(updateEnabled(tester), isFalse);
    });

    testWidgets('an https link clears the error and is saved as typed', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(linkField(), 'javascript:alert(1)');
      await tester.pump();
      await tester.enterText(linkField(), 'https://example.com/me');
      await tester.pump();

      expect(find.text('Enter a valid link.'), findsNothing);
      expect(updateEnabled(tester), isTrue);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect((firestore.writes.single.data!['links'] as Map)['custom link'], 'https://example.com/me');
    });
  });
}
