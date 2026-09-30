import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
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

  Future<void> pumpShell(WidgetTester tester, {double width = 390, double height = 844, double textScale = 1}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: prismDarkThemes.first.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const OnboardingV2Shell(),
      ),
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

  group('compact and landscape layouts', () {
    final viewports = <String, (double, double, double)>{
      '320x568 at 2x text': (320, 568, 2),
      '320x568 at 3x text': (320, 568, 3),
      '844x390 at 2x text': (844, 390, 2),
      '844x390 at 3x text': (844, 390, 3),
    };

    for (final entry in viewports.entries) {
      testWidgets('all five steps expose a reachable action at ${entry.key}', (tester) async {
        final (width, height, textScale) = entry.value;
        await pumpShell(tester, width: width, height: height, textScale: textScale);

        final steps = <(OnboardingV2Step, OnboardingV2State, String)>[
          (OnboardingV2Step.auth, OnboardingV2State.initial(), 'Continue with Google'),
          (
            OnboardingV2Step.interests,
            OnboardingV2State.initial().copyWith(
              step: OnboardingV2Step.interests,
              loadStatus: LoadStatus.success,
              interestsData: const OnboardingInterestsData(
                available: <String>['Nature', 'Space', 'Anime'],
                selected: <String>['Nature', 'Space', 'Anime'],
                categoryImages: <String, String>{},
              ),
            ),
            'Continue',
          ),
          (
            OnboardingV2Step.starterPack,
            OnboardingV2State.initial().copyWith(
              step: OnboardingV2Step.starterPack,
              loadStatus: LoadStatus.success,
              starterPackData: OnboardingStarterPackData(
                creators: List<OnboardingStarterCreatorEntity>.generate(
                  3,
                  (index) => OnboardingStarterCreatorEntity(
                    userId: 'u$index',
                    email: 'creator$index@example.com',
                    name: 'Creator $index',
                    photoUrl: '',
                    previewUrls: const <String>[],
                    rank: index,
                    followerCount: 1000,
                  ),
                ),
                selectedEmails: <String>{'creator0@example.com', 'creator1@example.com', 'creator2@example.com'},
              ),
            ),
            'Continue',
          ),
          (
            OnboardingV2Step.aiGenerate,
            OnboardingV2State.initial().copyWith(
              step: OnboardingV2Step.aiGenerate,
              aiData: const OnboardingAiData(
                prompt: 'a quiet mountain lake',
                stylePreset: AiStylePreset.nature,
                status: AiGenerateStatus.idle,
              ),
            ),
            'Generate',
          ),
          (
            OnboardingV2Step.firstWallpaper,
            OnboardingV2State.initial().copyWith(step: OnboardingV2Step.firstWallpaper),
            'Continue',
          ),
        ];

        for (final (step, state, label) in steps) {
          states.add(state);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          final Finder action = find.text(label);
          await tester.ensureVisible(action);
          expect(tester.getRect(action).overlaps(Offset.zero & Size(width, height)), isTrue);
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow on $step primary action at ${width}x$height with $textScale text',
          );
          await tester.tap(action);
          await tester.pump();
        }
      });
    }
  });
}
