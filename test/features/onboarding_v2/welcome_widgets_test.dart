import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/welcome_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/welcome_buttons.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/welcome_staggered_fade.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required bool reduceMotion, required Widget child}) => MaterialApp(
  theme: prismDarkThemes.first.theme,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: app!,
  ),
  home: Scaffold(body: child),
);

double _scaleOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byType(WelcomeArt).first, matching: find.byType(Transform)).first,
  );
  return transform.transform.getMaxScaleOnAxis();
}

void main() {
  group('WelcomeStaggeredFade', () {
    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.descendant(of: find.byType(WelcomeStaggeredFade), matching: find.byType(FadeTransition)),
        )
        .opacity
        .value;

    testWidgets('shows the child at once when the system asks for less motion', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: true,
          child: const WelcomeStaggeredFade(delay: Duration(milliseconds: 900), child: Text('hello')),
        ),
      );

      expect(opacity(tester), 1.0);
    });

    testWidgets('waits for the delay and then fades when motion is on', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: false,
          child: const WelcomeStaggeredFade(delay: Duration(milliseconds: 900), child: Text('hello')),
        ),
      );
      await tester.pump();

      expect(opacity(tester), 0.0);

      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump(PrismDurations.base);

      expect(opacity(tester), 1.0);
    });
  });

  group('WelcomeBackground', () {
    testWidgets('starts at the final scale when the system asks for less motion', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: true, child: const WelcomeBackground(visible: true)));
      await tester.pump();

      expect(_scaleOf(tester), closeTo(1.0, 0.0001));
    });

    testWidgets('plays the zoom reveal when motion is on', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: false, child: const WelcomeBackground(visible: true)));
      await tester.pump();

      expect(_scaleOf(tester), greaterThan(1.1));
      await tester.pump(WelcomeBackground.revealDuration);
    });

    testWidgets('fades out at once when the system asks for less motion', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: true, child: const WelcomeBackground(visible: false)));

      final fade = tester.widget<AnimatedOpacity>(
        find.descendant(of: find.byType(WelcomeBackground), matching: find.byType(AnimatedOpacity)),
      );
      expect(fade.duration, Duration.zero);
    });

    testWidgets('keeps a warm fill if the welcome wallpaper cannot decode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(width: 393, height: 852, child: WelcomeArt(assetPath: 'assets/images/does_not_exist.webp')),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == OnboardingAssets.fallbackFill),
        findsOneWidget,
      );
    });
  });

  group('WelcomePrimaryButton', () {
    Duration fadeDuration(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration;

    testWidgets('does not animate its state changes when the system asks for less motion', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: true,
          child: WelcomePrimaryButton(label: 'Continue', onPressed: () {}),
        ),
      );

      expect(fadeDuration(tester), Duration.zero);
    });

    testWidgets('animates its state changes when motion is on', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: false,
          child: WelcomePrimaryButton(label: 'Continue', onPressed: () {}),
        ),
      );

      expect(fadeDuration(tester), PrismDurations.fast);
    });

    testWidgets('screen readers hear the button label once', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: WelcomePrimaryButton(label: 'Continue with Google', onPressed: () {}),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(WelcomePrimaryButton)),
        matchesSemantics(
          label: 'Continue with Google',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    });

    testWidgets('an icon renders next to the label only when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: WelcomePrimaryButton(label: 'Continue with Apple', icon: Icons.apple, onPressed: () {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.apple), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: WelcomePrimaryButton(label: 'Continue with Google', onPressed: () {}),
          ),
        ),
      );

      expect(find.byType(Icon), findsNothing);
    });
  });
}
