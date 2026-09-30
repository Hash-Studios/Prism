import 'package:Prism/core/widgets/glint/glint.dart';
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

  group('the pre-prompt sheet', () {
    bool? answer;

    Future<void> openSheet(WidgetTester tester) async {
      answer = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answer = await NotificationPermissionPromptService.instance.askFirst(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> tapAndClose(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('explains the benefit with Glint before the system dialog', (tester) async {
      await openSheet(tester);

      expect(find.byType(Glint), findsOneWidget);
      expect(find.text('Get the Wall of the Day'), findsOneWidget);
      expect(find.text('One hand-picked wallpaper each morning. No spam.'), findsOneWidget);
      expect(find.text('Turn on notifications'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('Turn on notifications resolves true', (tester) async {
      await openSheet(tester);
      await tapAndClose(tester, 'Turn on notifications');

      expect(answer, isTrue);
    });

    testWidgets('Not now resolves false', (tester) async {
      await openSheet(tester);
      await tapAndClose(tester, 'Not now');

      expect(answer, isFalse);
    });
  });
}
