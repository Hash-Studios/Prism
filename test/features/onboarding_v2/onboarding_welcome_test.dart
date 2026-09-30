import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f0_auth_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_terms_row.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

void main() {
  late _MockOnboardingBloc bloc;
  late TapGestureRecognizer legalTap;
  int google = 0;
  int apple = 0;
  int browse = 0;
  bool? terms;

  setUp(() {
    bloc = _MockOnboardingBloc();
    legalTap = TapGestureRecognizer();
    google = apple = browse = 0;
    terms = null;
    when(() => bloc.state).thenReturn(OnboardingV2State.initial());
  });

  tearDown(() {
    legalTap.dispose();
    toasts.overlayResolver = null;
  });

  Future<void> pumpWelcome(WidgetTester tester, {required bool accepted, bool loading = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => bloc.state).thenReturn(OnboardingV2State.initial().copyWith(isAuthLoading: loading));
    await tester.pumpWidget(
      MaterialApp(
        theme: prismLightThemes.first.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              toasts.overlayResolver = () => Overlay.maybeOf(context);
              return BlocProvider<OnboardingV2Bloc>.value(
                value: bloc,
                child: F0AuthPage(
                  termsAccepted: accepted,
                  onTermsChanged: (value) => terms = value,
                  legalTap: legalTap,
                  onGoogle: () => google++,
                  onApple: () => apple++,
                  onBrowse: () => browse++,
                ),
              );
            },
          ),
        ),
      ),
    );
    // The staggered entrance starts on a timer, then animates on the next frames.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the welcome step shows the pitch and the terms row', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpWelcome(tester, accepted: false);

    expect(find.text('Your screen, reimagined.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Browse without an account'), findsNothing);
    expect(tester.getSemantics(find.byType(OnboardingTermsRow)).label, 'I agree to the Terms of Use');
    semantics.dispose();
  });

  testWidgets('an unticked box blocks sign-in, shakes the row and says why', (tester) async {
    await pumpWelcome(tester, accepted: false);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(google, 0);
    expect(find.text('Agree to the Terms of Use to continue.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('a ticked box lets the sign-in button through', (tester) async {
    await pumpWelcome(tester, accepted: true);

    await tester.tap(find.text('Continue with Google'));

    expect(google, 1);
  });

  testWidgets('tapping the terms row toggles the box', (tester) async {
    await pumpWelcome(tester, accepted: false);

    await tester.tapAt(tester.getTopLeft(find.byIcon(Icons.check_rounded)));

    expect(terms, isTrue);
  });

  testWidgets('iOS adds Apple and guest browsing, both behind the same gate', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpWelcome(tester, accepted: true);
      expect(find.text('Continue with Apple'), findsOneWidget);

      await tester.tap(find.text('Continue with Apple'));
      await tester.tap(find.text('Browse without an account'));

      expect(apple, 1);
      expect(browse, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('guest browsing on iOS also needs the terms', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpWelcome(tester, accepted: false);

      await tester.tap(find.text('Browse without an account'));
      await tester.pump();

      expect(browse, 0);
      expect(find.text('Agree to the Terms of Use to continue.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a running sign-in puts a spinner in the button and blocks a second tap', (tester) async {
    await pumpWelcome(tester, accepted: true, loading: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(CircularProgressIndicator));
    expect(google, 0);
  });

  group('step frame', () {
    Future<void> pumpFrame(WidgetTester tester, {VoidCallback? onSkip, VoidCallback? onPrimary}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: prismDarkThemes.first.theme,
          home: Scaffold(
            body: OnboardingFrame(
              title: 'A title',
              body: 'One line of body text.',
              primaryLabel: 'Continue',
              onPrimary: onPrimary,
              onSkip: onSkip,
              secondary: const Text('Later'),
              child: const Center(child: Text('step content')),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the title, body, content, primary action and the secondary one', (tester) async {
      var continued = 0;
      await pumpFrame(tester, onPrimary: () => continued++);

      expect(find.text('A title'), findsOneWidget);
      expect(find.text('One line of body text.'), findsOneWidget);
      expect(find.text('step content'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      await tester.tap(find.text('Continue'));
      expect(continued, 1);
    });

    testWidgets('Skip appears only when there is a skip action', (tester) async {
      var skipped = 0;
      await pumpFrame(tester, onSkip: () => skipped++);

      await tester.tap(find.text('Skip'));
      expect(skipped, 1);
    });

    testWidgets('a null primary action disables the button', (tester) async {
      await pumpFrame(tester);

      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed, isNull);
    });
  });

  group('progress bar', () {
    Future<void> pumpBar(WidgetTester tester, int step) => tester.pumpWidget(
      MaterialApp(
        theme: prismDarkThemes.first.theme,
        home: Scaffold(body: OnboardingProgressBar(step: step)),
      ),
    );

    double fill(WidgetTester tester) =>
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;

    testWidgets('the fill slides to the new step', (tester) async {
      await pumpBar(tester, 1);
      expect(fill(tester), 0.25);

      await pumpBar(tester, 3);
      await tester.pump(const Duration(milliseconds: 120));
      expect(fill(tester), inExclusiveRange(0.25, 0.75));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fill(tester), 0.75);
    });

    testWidgets('it tells screen readers the step', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpBar(tester, 2);

      expect(find.bySemanticsLabel('Onboarding progress'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Onboarding progress')).value, 'Step 2 of 4');
      semantics.dispose();
    });

    testWidgets('reduce motion jumps straight to the step', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: prismDarkThemes.first.theme,
          builder: (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
          home: const Scaffold(body: OnboardingProgressBar(step: 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: prismDarkThemes.first.theme,
          builder: (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
          home: const Scaffold(body: OnboardingProgressBar(step: 4)),
        ),
      );
      await tester.pump();

      expect(fill(tester), 1);
    });
  });
}
