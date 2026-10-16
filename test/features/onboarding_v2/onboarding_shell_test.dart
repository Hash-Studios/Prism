import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f0_auth_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f1_interests_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f2_starter_pack_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f3_ai_generate_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f4_first_wallpaper_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_progress_indicator.dart';
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

  OnboardingV2State onStep(OnboardingV2Step step, {ActionStatus action = ActionStatus.idle}) =>
      OnboardingV2State.initial().copyWith(step: step, loadStatus: LoadStatus.loading, actionStatus: action);

  Future<void> goTo(WidgetTester tester, OnboardingV2State state) async {
    states.add(state);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  int? progressStep(WidgetTester tester) =>
      tester.widgetList<OnboardingProgressIndicator>(find.byType(OnboardingProgressIndicator)).firstOrNull?.step;

  testWidgets('starts on the redesign welcome page with none of the shared step overlay', (tester) async {
    await pumpShell(tester);

    verify(() => bloc.add(const OnboardingV2Event.started())).called(1);
    expect(find.text('Your screen, reimagined.'), findsOneWidget);
    expect(find.byType(F0AuthPage), findsOneWidget);
    expect(find.byType(OnboardingProgressIndicator), findsNothing);
    expect(find.byType(OnboardingPrimaryButton), findsNothing);
  });

  testWidgets('steps 1 to 4 use the current layout: headline, progress dots, button and helper text', (tester) async {
    await pumpShell(tester);

    await goTo(tester, onStep(OnboardingV2Step.interests));

    expect(find.byType(F0AuthPage), findsNothing);
    expect(find.text('Pick your vibe'), findsOneWidget);
    expect(find.byType(F1InterestsPage), findsOneWidget);
    expect(progressStep(tester), 1);
    expect(find.byType(OnboardingPrimaryButton), findsOneWidget);
    expect(find.text('continue'), findsOneWidget);

    await goTo(tester, onStep(OnboardingV2Step.starterPack));
    expect(find.text('Find your people'), findsOneWidget);
    expect(find.byType(F2StarterPackPage), findsOneWidget);
    expect(progressStep(tester), 2);

    await goTo(tester, onStep(OnboardingV2Step.aiGenerate));
    expect(find.text('Create your\nfirst wallpaper'), findsOneWidget);
    expect(find.byType(F3AiGeneratePage), findsOneWidget);
    expect(progressStep(tester), 3);
    expect(find.text('generate my wallpaper'), findsOneWidget);

    await goTo(tester, onStep(OnboardingV2Step.firstWallpaper));
    expect(find.text('Make it yours'), findsOneWidget);
    expect(find.byType(F4FirstWallpaperPage), findsOneWidget);
    expect(progressStep(tester), 4);
    expect(find.text('set as wallpaper'), findsOneWidget);
  });

  testWidgets('going back to the welcome step brings the redesign page back', (tester) async {
    await pumpShell(tester);
    await goTo(tester, onStep(OnboardingV2Step.interests));

    await goTo(tester, OnboardingV2State.initial());

    expect(find.byType(F0AuthPage), findsOneWidget);
    expect(find.byType(OnboardingProgressIndicator), findsNothing);
  });

  testWidgets('a failed save tells the user instead of failing silently', (tester) async {
    await pumpShell(tester);
    await goTo(tester, onStep(OnboardingV2Step.interests));

    states.add(onStep(OnboardingV2Step.interests, action: ActionStatus.failure));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text("Couldn't save your picks. Try again."), findsOneWidget);
    expect(find.text('try again'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('system text above the cap is held at the cap', (tester) async {
    await pumpShell(tester, textScale: 3);

    final BuildContext inside = tester.element(find.text('Your screen, reimagined.'));
    expect(MediaQuery.textScalerOf(inside).scale(10), closeTo(10 * OnboardingLayout.maxTextScale, 0.001));
  });

  testWidgets('on a wide screen the step overlay sits in the same capped column', (tester) async {
    await pumpShell(tester, width: 1280, height: 800);
    await goTo(tester, onStep(OnboardingV2Step.interests));

    expect(
      tester.getSize(find.byType(OnboardingPrimaryButton)).width,
      lessThanOrEqualTo(OnboardingLayout.maxContentWidth),
    );
    expect(tester.getCenter(find.byType(OnboardingPrimaryButton)).dx, closeTo(640, 0.5));
  });

  group('compact and landscape layouts', () {
    final viewports = <String, (double, double, double)>{
      '320x568 at 1x text': (320, 568, 1),
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
            'continue',
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
            'continue',
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
            'generate my wallpaper',
          ),
          (
            OnboardingV2Step.firstWallpaper,
            OnboardingV2State.initial().copyWith(step: OnboardingV2Step.firstWallpaper),
            'set as wallpaper',
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
