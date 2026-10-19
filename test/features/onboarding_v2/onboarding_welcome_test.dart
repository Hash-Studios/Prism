import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f0_auth_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_terms_row.dart';
import 'package:Prism/l10n/l10n.dart';
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
  late TapGestureRecognizer privacyTap;
  int google = 0;
  int apple = 0;
  int browse = 0;
  bool? terms;

  setUp(() {
    bloc = _MockOnboardingBloc();
    legalTap = TapGestureRecognizer();
    privacyTap = TapGestureRecognizer();
    google = apple = browse = 0;
    terms = null;
    when(() => bloc.state).thenReturn(OnboardingV2State.initial());
  });

  tearDown(() {
    legalTap.dispose();
    privacyTap.dispose();
    toasts.overlayResolver = null;
  });

  Future<void> pumpWelcome(WidgetTester tester, {required bool accepted, bool loading = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => bloc.state).thenReturn(OnboardingV2State.initial().copyWith(isAuthLoading: loading));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
                  privacyTap: privacyTap,
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
    expect(find.text('Browse without an account'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(OnboardingTermsRow)).label,
      'By continuing you agree to the Terms and Privacy policy',
    );
    semantics.dispose();
  });

  testWidgets('an unticked box blocks sign-in, shakes the row and says why', (tester) async {
    await pumpWelcome(tester, accepted: false);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(google, 0);
    expect(find.text('Please agree to the Terms and Privacy policy first.'), findsOneWidget);
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

  testWidgets('Android allows guest browsing behind the terms gate', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pumpWelcome(tester, accepted: false);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Browse without an account'), findsOneWidget);
      await tester.tap(find.text('Browse without an account'));
      await tester.pump();
      expect(browse, 0);
      expect(find.text('Please agree to the Terms and Privacy policy first.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await pumpWelcome(tester, accepted: true);
      await tester.tap(find.text('Browse without an account'));
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
      expect(find.text('Please agree to the Terms and Privacy policy first.'), findsOneWidget);
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
}
