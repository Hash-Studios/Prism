import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('screen readers hear the button label once', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('an icon renders next to the label only when provided', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: OnboardingPrimaryButton(label: 'Continue with Apple', icon: Icons.apple, onPressed: () {}),
        ),
      ),
    );

    expect(find.byIcon(Icons.apple), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: OnboardingPrimaryButton(label: 'continue with Google', onPressed: () {}),
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('disabled stays a solid pill with 55 percent text instead of fading out', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: OnboardingPrimaryButton(label: 'Continue', enabled: false, onPressed: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(tester.widget<Text>(find.text('Continue')).style!.color!.a, closeTo(0.55, 0.01));
    final BoxDecoration fill =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(of: find.byType(OnboardingPrimaryButton), matching: find.byType(AnimatedContainer)),
                )
                .decoration!
            as BoxDecoration;
    expect(fill.color!.a, greaterThanOrEqualTo(0.85));
  });
}
