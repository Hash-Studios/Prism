import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sign in plays one tap haptic and opens the sign-in sheet', (tester) async {
    final bool wasEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    final List<Object?> haptics = <Object?>[];
    const MethodChannel hapticsChannel = MethodChannel('prism/haptics');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, (MethodCall call) async {
      haptics.add(call.arguments);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, null);
      PrismHaptics.enabled = wasEnabled;
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SignInPrompt(feature: 'streaks')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(PrismButton, 'Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(haptics, <Object?>['tap'], reason: "GlintState's PrismButton owns the tap haptic");
    expect(find.text('Sign in to Prism'), findsOneWidget);
  });
}
