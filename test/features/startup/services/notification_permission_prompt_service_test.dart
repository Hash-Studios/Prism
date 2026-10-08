import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const canAsk = NotificationPermissionPromptService.canAsk;

  test('Android asks even though it reports denied before the first ask', () {
    expect(canAsk(AuthorizationStatus.denied, TargetPlatform.android), isTrue);
  });

  test('iOS treats denied as final', () {
    expect(canAsk(AuthorizationStatus.denied, TargetPlatform.iOS), isFalse);
  });

  test('an undecided status can always be asked', () {
    expect(canAsk(AuthorizationStatus.notDetermined, TargetPlatform.iOS), isTrue);
    expect(canAsk(AuthorizationStatus.notDetermined, TargetPlatform.android), isTrue);
  });

  test('iOS provisional access can ask for full access, Android has no provisional', () {
    expect(canAsk(AuthorizationStatus.provisional, TargetPlatform.iOS), isTrue);
    expect(canAsk(AuthorizationStatus.provisional, TargetPlatform.android), isFalse);
  });

  test('iOS re-checks once after the provisional-only V1 prompt, Android does not', () {
    const prompted = NotificationPermissionPromptService.alreadyPrompted;
    expect(prompted(v1: true, v2: false, platform: TargetPlatform.iOS), isFalse);
    expect(prompted(v1: true, v2: false, platform: TargetPlatform.android), isTrue);
    expect(prompted(v1: false, v2: true, platform: TargetPlatform.iOS), isTrue);
    expect(prompted(v1: false, v2: false, platform: TargetPlatform.android), isFalse);
  });

  group('soft prompt before the system prompt', () {
    late int requests;
    Future<int> request() async => ++requests;

    setUp(() {
      requests = 0;
      StartupModalSlot.reset();
    });

    Future<Future<int?>> openPrompt(WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext builderContext) {
              context = builderContext;
              return const SizedBox();
            },
          ),
        ),
      );
      final Future<int?> result = NotificationPermissionPromptService.requestAfterSoftPrompt<int>(
        context,
        requestPermission: request,
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('asks in one line, and Not now never calls the system prompt', (WidgetTester tester) async {
      final Future<int?> result = await openPrompt(tester);

      expect(find.text('Get the Wall of the Day and streak reminders?'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(await result, isNull);
      expect(requests, 0);
    });

    testWidgets('Turn on calls the system prompt once', (WidgetTester tester) async {
      final Future<int?> result = await openPrompt(tester);

      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();

      expect(await result, 1);
      expect(requests, 1);
    });

    testWidgets('closing the sheet without a choice does not call the system prompt', (WidgetTester tester) async {
      final Future<int?> result = await openPrompt(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await result, isNull);
      expect(requests, 0);
    });

    testWidgets('does not show a second startup sheet in the same session', (WidgetTester tester) async {
      StartupModalSlot.shown.value = true;
      final Future<int?> result = await openPrompt(tester);

      expect(find.text('Turn on'), findsNothing);
      expect(await result, isNull);
      expect(requests, 0);
    });

    testWidgets('claims the slot so the next startup sheet waits for another session', (WidgetTester tester) async {
      final Future<int?> result = await openPrompt(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      await result;

      expect(StartupModalSlot.shown.value, isTrue);
      expect(StartupModalSlot.tryClaim(), isFalse);
    });
  });
}
