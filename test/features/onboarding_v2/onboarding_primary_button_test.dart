import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('screen readers hear the button label once', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: OnboardingPrimaryButton(label: 'continue with Google', onPressed: () {}),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(OnboardingPrimaryButton)),
      matchesSemantics(
        label: 'continue with Google',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
  });
}
