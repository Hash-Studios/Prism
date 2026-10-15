import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f3_ai_generate_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_staggered_fade.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

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
    find.descendant(of: find.byType(OnboardingBackground).first, matching: find.byType(Transform)).first,
  );
  return transform.transform.getMaxScaleOnAxis();
}

void main() {
  group('OnboardingStaggeredFade', () {
    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.descendant(of: find.byType(OnboardingStaggeredFade), matching: find.byType(FadeTransition)),
        )
        .opacity
        .value;

    testWidgets('shows the child at once when the system asks for less motion', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: true,
          child: const OnboardingStaggeredFade(delay: Duration(milliseconds: 900), child: Text('hello')),
        ),
      );

      expect(opacity(tester), 1.0);
    });

    testWidgets('waits for the delay and then fades when motion is on', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: false,
          child: const OnboardingStaggeredFade(delay: Duration(milliseconds: 900), child: Text('hello')),
        ),
      );
      await tester.pump();

      expect(opacity(tester), 0.0);

      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump(PrismDurations.base);

      expect(opacity(tester), 1.0);
    });
  });

  group('OnboardingStepBackground', () {
    testWidgets('starts at the final scale when the system asks for less motion', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: true, child: const OnboardingStepBackground(visible: true)));
      await tester.pump();

      expect(_scaleOf(tester), closeTo(1.0, 0.0001));
    });

    testWidgets('plays the zoom reveal when motion is on', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: false, child: const OnboardingStepBackground(visible: true)));
      await tester.pump();

      expect(_scaleOf(tester), greaterThan(1.1));
      await tester.pump(OnboardingMotion.backgroundReveal);
    });

    testWidgets('fades out at once when the system asks for less motion', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: true, child: const OnboardingStepBackground(visible: false)));

      final fade = tester.widget<AnimatedOpacity>(
        find.descendant(of: find.byType(OnboardingStepBackground), matching: find.byType(AnimatedOpacity)),
      );
      expect(fade.duration, Duration.zero);
    });
  });

  group('OnboardingPrimaryButton', () {
    Duration fadeDuration(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration;

    testWidgets('does not animate its state changes when the system asks for less motion', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: true,
          child: OnboardingPrimaryButton(label: 'continue', onPressed: () {}),
        ),
      );

      expect(fadeDuration(tester), Duration.zero);
    });

    testWidgets('animates its state changes when motion is on', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: false,
          child: OnboardingPrimaryButton(label: 'continue', onPressed: () {}),
        ),
      );

      expect(fadeDuration(tester), PrismDurations.fast);
    });
  });

  group('F3AiGeneratePage', () {
    Future<void> pumpPage(WidgetTester tester, {required bool reduceMotion}) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bloc = _MockOnboardingBloc();
      whenListen(bloc, const Stream<OnboardingV2State>.empty(), initialState: OnboardingV2State.initial());
      await tester.pumpWidget(
        _app(
          reduceMotion: reduceMotion,
          child: BlocProvider<OnboardingV2Bloc>.value(value: bloc, child: const F3AiGeneratePage()),
        ),
      );
    }

    Duration previewDuration(WidgetTester tester) =>
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher).first).duration;

    testWidgets('swaps the preview at once when the system asks for less motion', (tester) async {
      await pumpPage(tester, reduceMotion: true);

      expect(previewDuration(tester), Duration.zero);
    });

    testWidgets('cross-fades the preview when motion is on', (tester) async {
      await pumpPage(tester, reduceMotion: false);

      expect(previewDuration(tester), isNot(Duration.zero));
    });
  });
}
