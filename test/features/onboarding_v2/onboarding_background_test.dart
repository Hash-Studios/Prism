import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps a warm fill if the welcome wallpaper cannot decode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 393,
          height: 852,
          child: OnboardingBackground(
            assetPath: 'assets/images/does_not_exist.webp',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == OnboardingColors.fallbackFill,
      ),
      findsOneWidget,
    );
  });
}
