import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

void main() {
  late _MockOnboardingBloc bloc;
  late StreamController<OnboardingV2State> states;
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();

  setUpAll(() => registerFallbackValue(const OnboardingV2Event.started()));

  setUp(() {
    bloc = _MockOnboardingBloc();
    states = StreamController<OnboardingV2State>.broadcast();
    whenListen(bloc, states.stream, initialState: OnboardingV2State.initial());
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    getIt.registerFactory<OnboardingV2Bloc>(() => bloc);
    toasts.overlayResolver = () => navigator.currentState?.overlay;
  });

  tearDown(() async {
    await states.close();
    toasts.overlayResolver = null;
    await getIt.reset();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, theme: prismDarkThemes.first.theme, home: const OnboardingV2Shell()),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  double barOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: find.byType(OnboardingProgressBar), matching: find.byType(AnimatedOpacity)),
      )
      .opacity;

  OnboardingV2State onStep(OnboardingV2Step step, {ActionStatus action = ActionStatus.idle}) =>
      OnboardingV2State.initial().copyWith(step: step, loadStatus: LoadStatus.loading, actionStatus: action);

  testWidgets('starts on the welcome step with the progress bar hidden', (tester) async {
    await pumpShell(tester);

    verify(() => bloc.add(const OnboardingV2Event.started())).called(1);
    expect(find.text('Your screen, reimagined.'), findsOneWidget);
    expect(barOpacity(tester), 0);
  });

  testWidgets('moving to a step cross-fades the page and moves the progress bar on', (tester) async {
    await pumpShell(tester);

    states.add(onStep(OnboardingV2Step.interests));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Pick your vibe'), findsOneWidget);
    expect(find.text('Your screen, reimagined.'), findsNothing);
    expect(barOpacity(tester), 1);
    expect(tester.widget<OnboardingProgressBar>(find.byType(OnboardingProgressBar)).step, 1);

    states.add(onStep(OnboardingV2Step.starterPack));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Find your people'), findsOneWidget);
    expect(tester.widget<OnboardingProgressBar>(find.byType(OnboardingProgressBar)).step, 2);
  });

  testWidgets('a failed save tells the user instead of failing silently', (tester) async {
    await pumpShell(tester);
    states.add(onStep(OnboardingV2Step.interests));
    await tester.pump(const Duration(milliseconds: 400));

    states.add(onStep(OnboardingV2Step.interests, action: ActionStatus.failure));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });
}
