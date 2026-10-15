import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f3_ai_generate_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_progress_indicator.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_staggered_fade.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

Widget _app({required bool reduceMotion, required Widget child}) => MaterialApp(
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
    testWidgets('shows the child at once when the system asks for less motion', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: true,
          child: const OnboardingStaggeredFade(delay: Duration(milliseconds: 900), child: Text('hello')),
        ),
      );

      final fade = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(fade.opacity, 1.0);
      expect(fade.duration, Duration.zero);
    });

    testWidgets('waits for the delay and then fades when motion is on', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: false,
          child: const OnboardingStaggeredFade(delay: Duration(milliseconds: 900), child: Text('hello')),
        ),
      );
      await tester.pump();

      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0.0);

      await tester.pump(const Duration(milliseconds: 950));

      final fade = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(fade.opacity, 1.0);
      expect(fade.duration, OnboardingMotion.fade);
      await tester.pump(OnboardingMotion.fade);
    });
  });

  group('OnboardingStepBackground', () {
    testWidgets('starts at the final scale when the system asks for less motion', (tester) async {
      await tester.pumpWidget(
        _app(reduceMotion: true, child: const OnboardingStepBackground(step: OnboardingV2Step.auth)),
      );
      await tester.pump();

      expect(_scaleOf(tester), closeTo(1.0, 0.0001));
    });

    testWidgets('plays the zoom reveal when motion is on', (tester) async {
      await tester.pumpWidget(
        _app(reduceMotion: false, child: const OnboardingStepBackground(step: OnboardingV2Step.auth)),
      );
      await tester.pump();

      expect(_scaleOf(tester), greaterThan(1.1));
      await tester.pump(OnboardingMotion.backgroundReveal);
    });

    testWidgets('jumps to the new blur on a step change when the system asks for less motion', (tester) async {
      Future<void> pumpStep(OnboardingV2Step step) =>
          tester.pumpWidget(_app(reduceMotion: true, child: OnboardingStepBackground(step: step)));
      await pumpStep(OnboardingV2Step.auth);
      await pumpStep(OnboardingV2Step.starterPack);
      await tester.pump();

      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(tester.widget<ImageFiltered>(find.byType(ImageFiltered)).imageFilter.toString(), contains('70'));
    });

    testWidgets('eases into the new blur when motion is on', (tester) async {
      Future<void> pumpStep(OnboardingV2Step step) =>
          tester.pumpWidget(_app(reduceMotion: false, child: OnboardingStepBackground(step: step)));
      await pumpStep(OnboardingV2Step.auth);
      await pumpStep(OnboardingV2Step.starterPack);
      await tester.pump();

      expect(find.byType(ImageFiltered), findsNothing);
      await tester.pump(OnboardingMotion.backgroundReveal);
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
      expect(tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration, Duration.zero);
    });

    testWidgets('animates its state changes when motion is on', (tester) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: false,
          child: OnboardingPrimaryButton(label: 'continue', onPressed: () {}),
        ),
      );

      expect(fadeDuration(tester), OnboardingMotion.short);
    });
  });

  group('OnboardingProgressIndicator', () {
    Iterable<Duration> dotDurations(WidgetTester tester) =>
        tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).map((c) => c.duration);

    testWidgets('moves the active dot at once when the system asks for less motion', (tester) async {
      await tester.pumpWidget(
        _app(reduceMotion: true, child: const OnboardingProgressIndicator(step: 2, totalSteps: 4)),
      );

      expect(dotDurations(tester), everyElement(Duration.zero));
    });

    testWidgets('animates the active dot when motion is on', (tester) async {
      await tester.pumpWidget(
        _app(reduceMotion: false, child: const OnboardingProgressIndicator(step: 2, totalSteps: 4)),
      );

      expect(dotDurations(tester), everyElement(OnboardingMotion.normal));
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

    testWidgets('swaps the preview at once when the system asks for less motion', (tester) async {
      await pumpPage(tester, reduceMotion: true);

      expect(tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration, Duration.zero);
    });

    testWidgets('cross-fades the preview when motion is on', (tester) async {
      await pumpPage(tester, reduceMotion: false);

      expect(tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration, isNot(Duration.zero));
    });
  });
}
