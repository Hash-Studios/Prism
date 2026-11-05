import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('retargeting blur keeps the animation chain free of curved listener nodes', (tester) async {
    OnboardingV2Step step = OnboardingV2Step.interests;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Stack(
            children: [
              OnboardingStepBackground(step: step),
              Positioned(
                child: TextButton(
                  onPressed: () => setState(() {
                    step = step == OnboardingV2Step.starterPack
                        ? OnboardingV2Step.interests
                        : OnboardingV2Step.starterPack;
                  }),
                  child: const Text('retarget'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (int i = 0; i < 6; i++) {
      await tester.tap(find.text('retarget'));
      await tester.pump(const Duration(milliseconds: 40));
    }

    final AnimatedBuilder blurBuilder = tester
        .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
        .firstWhere((builder) => builder.animation is Animation<double>);
    Animation<double> animation = blurBuilder.animation as Animation<double>;
    while (animation is AnimationWithParentMixin<double>) {
      expect(animation, isNot(isA<CurvedAnimation>()));
      animation = (animation as AnimationWithParentMixin<double>).parent;
    }
    expect(animation, isA<AnimationController>());
  });

  testWidgets('keeps a warm fill if the welcome wallpaper cannot decode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 393,
          height: 852,
          child: OnboardingBackground(assetPath: 'assets/images/does_not_exist.webp'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == OnboardingColors.fallbackFill),
      findsOneWidget,
    );
  });
}
