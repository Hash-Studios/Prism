import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/reject_reasons.dart';
import 'package:Prism/features/admin_review/views/widgets/reject_reason_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, Future<void> Function(String reason) onSubmit) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRejectReasonSheet(context, onSubmit: onSubmit),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  test('rejection reasons stay in their stable UI order', () {
    expect(rejectReasons, <RejectReason>[
      RejectReason.lowResolution,
      RejectReason.watermark,
      RejectReason.blurry,
      RejectReason.copyright,
      RejectReason.duplicate,
      RejectReason.notWallpaper,
      RejectReason.other,
    ]);
  });

  testWidgets('each preset uses its intended creator-facing text without email or blame', (tester) async {
    const List<(String, String)> presets = <(String, String)>[
      ('Low resolution', 'The resolution is too low. Upload an image with at least 1080 px on the short side.'),
      ('Watermark', 'The image has a watermark. Upload a version without it.'),
      ('Blurry', 'The image is blurry or heavily compressed. Upload a sharper version.'),
      (
        'Copyright',
        'This image may be the work of someone else. Upload only wallpapers you made or have the rights to.',
      ),
      ('Duplicate', 'This wallpaper is a duplicate of one that is already on Prism.'),
      ('Not a wallpaper', 'This image does not work as a phone wallpaper. Use a portrait image that fills the screen.'),
    ];
    await openSheet(tester, (_) async {});

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    for (final (String label, String copy) in presets) {
      expect(find.text(label), findsOneWidget);
      expect(copy, isNot(contains('@')), reason: label);
      expect(copy.toLowerCase(), isNot(contains('you failed')), reason: label);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(field.controller!.text, copy, reason: label);
    }
    expect(find.text('Other'), findsOneWidget);
    await tester.tap(find.text('Other'));
    await tester.pump();
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('the sheet submits the picked reason, which is how a swipe reject reads it', (tester) async {
    String? result;
    await openSheet(tester, (reason) async => result = reason);

    await tester.tap(find.text('Duplicate'));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pumpAndSettle();

    expect(result, 'This wallpaper is a duplicate of one that is already on Prism.');
    expect(find.byType(PrismSheetBody), findsNothing);
  });

  testWidgets('the confirm button submits the exact reason with one tap haptic', (tester) async {
    final bool previousHapticsEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    addTearDown(() => PrismHaptics.enabled = previousHapticsEnabled);
    final List<Object?> played = <Object?>[];
    const MethodChannel haptics = MethodChannel('prism/haptics');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, (call) async {
      played.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, null));
    String? submittedReason;
    await openSheet(tester, (reason) async => submittedReason = reason);

    await tester.tap(find.text('Duplicate'));
    await tester.pump();
    played.clear();
    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pumpAndSettle();

    expect(submittedReason, 'This wallpaper is a duplicate of one that is already on Prism.');
    expect(played, <Object?>['tap']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the sheet asks for a reason and submits nothing on cancel', (tester) async {
    String? result = 'unset';
    await openSheet(tester, (reason) async => result = reason);

    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pump();
    expect(find.text('Enter a reason before rejecting this item.'), findsOneWidget);
    expect(result, 'unset');

    await tester.tap(find.widgetWithText(PrismButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, 'unset');
    expect(find.byType(PrismSheetBody), findsNothing);
  });
}
