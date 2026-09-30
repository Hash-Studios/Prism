import 'dart:ui' as ui;

import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f1_interests_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f2_starter_pack_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f3_ai_generate_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f4_first_wallpaper_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_wallpaper_vm.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/interest_category_tile.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

OnboardingStarterCreatorEntity _creator(int i) => OnboardingStarterCreatorEntity(
  userId: 'u$i',
  email: 'creator$i@example.com',
  name: 'Creator $i',
  photoUrl: '',
  previewUrls: const <String>[],
  rank: i,
  followerCount: 1200 * i,
);

void main() {
  late _MockOnboardingBloc bloc;

  setUpAll(() => registerFallbackValue(const OnboardingV2Event.started()));

  setUp(() => bloc = _MockOnboardingBloc());

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page,
    OnboardingV2State state, {
    ThemeData? theme,
    double height = 844,
    double width = 390,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? prismDarkThemes.first.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: BlocProvider<OnboardingV2Bloc>.value(value: bloc, child: page),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  OnboardingV2State interests({
    List<String> available = const <String>[],
    List<String> selected = const <String>[],
    LoadStatus load = LoadStatus.success,
    ActionStatus action = ActionStatus.idle,
  }) => OnboardingV2State.initial().copyWith(
    step: OnboardingV2Step.interests,
    loadStatus: load,
    actionStatus: action,
    interestsData: OnboardingInterestsData(available: available, selected: selected, categoryImages: const {}),
  );

  group('interests', () {
    testWidgets('screen-reader activation toggles a category and updates its selected semantics', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      bool selected = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: prismDarkThemes.first.theme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => InterestCategoryTile(
                name: 'Nature',
                isSelected: selected,
                onTap: () => setState(() => selected = !selected),
              ),
            ),
          ),
        ),
      );

      final Finder category = find.bySemanticsLabel('Nature');
      final SemanticsNode node = tester.getSemantics(category);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
      );
      await tester.pump();

      expect(tester.getSemantics(category).getSemanticsData().flagsCollection.isSelected, ui.Tristate.isTrue);
      semantics.dispose();
    });

    testWidgets('shows a skeleton while categories load and keeps Continue off', (tester) async {
      await pumpPage(tester, const F1InterestsPage(), interests(load: LoadStatus.loading));

      expect(find.text('Pick your vibe'), findsOneWidget);
      expect(find.byType(PrismSkeleton), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed, isNull);
    });

    testWidgets('counts picks and lets the user continue from the third', (tester) async {
      const all = <String>['Nature', 'Space', 'Anime', 'Cars'];
      await pumpPage(tester, const F1InterestsPage(), interests(available: all, selected: <String>['Nature']));

      expect(find.text('1 of 3 picked'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed, isNull);

      await tester.tap(find.bySemanticsLabel('Space'));
      verify(() => bloc.add(const OnboardingV2Event.interestToggled('Space'))).called(1);

      await pumpPage(
        tester,
        const F1InterestsPage(),
        interests(available: all, selected: <String>['Nature', 'Space', 'Anime']),
      );
      expect(find.text('3 picked'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      verify(() => bloc.add(const OnboardingV2Event.interestsConfirmed())).called(1);
    });

    testWidgets('an empty list says so, offers a retry and lets the user skip', (tester) async {
      await pumpPage(tester, const F1InterestsPage(), interests());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Could not load categories'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      verify(() => bloc.add(const OnboardingV2Event.started())).called(1);
      await tester.tap(find.text('Skip'));
      verify(() => bloc.add(const OnboardingV2Event.aiGenerationStepContinued())).called(1);
    });
  });

  group('starter pack', () {
    OnboardingV2State pack({
      List<OnboardingStarterCreatorEntity> creators = const <OnboardingStarterCreatorEntity>[],
      Set<String> selected = const <String>{},
      LoadStatus load = LoadStatus.success,
    }) => OnboardingV2State.initial().copyWith(
      step: OnboardingV2Step.starterPack,
      loadStatus: load,
      starterPackData: OnboardingStarterPackData(creators: creators, selectedEmails: selected),
    );

    testWidgets('shows a skeleton while creators load', (tester) async {
      await pumpPage(tester, const F2StarterPackPage(), pack(load: LoadStatus.loading));

      expect(find.text('Find your people'), findsOneWidget);
      expect(find.byType(PrismSkeleton), findsOneWidget);
    });

    testWidgets('follow and following swap, and the counter follows the selection', (tester) async {
      final creators = <OnboardingStarterCreatorEntity>[_creator(1), _creator(2), _creator(3)];
      await pumpPage(
        tester,
        const F2StarterPackPage(),
        pack(creators: creators, selected: {creators[0].email}),
        height: 1800,
      );

      expect(find.text('1 of 3 followed'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Follow'), findsNWidgets(2));
      expect(find.text('1.2K followers'), findsOneWidget);

      await tester.tap(find.text('Follow').first);
      verify(() => bloc.add(OnboardingV2Event.creatorFollowToggled(creators[1].email))).called(1);
    });

    testWidgets('an empty pack explains itself and lets the user move on', (tester) async {
      await pumpPage(tester, const F2StarterPackPage(), pack());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No creators to suggest yet'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      verify(() => bloc.add(const OnboardingV2Event.aiGenerationStepContinued())).called(1);
    });
  });

  group('ai generate', () {
    OnboardingV2State ai(AiGenerateStatus status) => OnboardingV2State.initial().copyWith(
      step: OnboardingV2Step.aiGenerate,
      aiData: OnboardingAiData(prompt: 'a misty mountain range', stylePreset: AiStylePreset.nature, status: status),
    );

    testWidgets('idle shows the prompt, the style and a Generate button that requests a wallpaper', (tester) async {
      await pumpPage(tester, const F3AiGeneratePage(), ai(AiGenerateStatus.idle));

      expect(find.text('Create your first wallpaper'), findsOneWidget);
      expect(find.text('a misty mountain range'), findsOneWidget);
      expect(find.text('Nature'), findsOneWidget);
      expect(find.text('Your wallpaper will appear here.'), findsOneWidget);

      await tester.tap(find.text('Generate'));
      final verification = verify(() => bloc.add(captureAny()));
      expect(verification.captured.single, isA<OnboardingV2Event>());
    });

    testWidgets('loading shows Glint with a status line and a busy button', (tester) async {
      await pumpPage(tester, const F3AiGeneratePage(), ai(AiGenerateStatus.loading));

      expect(find.byType(Glint), findsOneWidget);
      expect(find.text('Crafting your wallpaper…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('failure says what happened and the button becomes Try again', (tester) async {
      await pumpPage(tester, const F3AiGeneratePage(), ai(AiGenerateStatus.failure));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Could not generate it'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Skip moves on to the first wallpaper', (tester) async {
      await pumpPage(tester, const F3AiGeneratePage(), ai(AiGenerateStatus.idle));

      await tester.tap(find.text('Skip'));
      verify(() => bloc.add(const OnboardingV2Event.aiGenerationStepContinued())).called(1);
    });
  });

  group('first wallpaper', () {
    OnboardingV2State wall({
      OnboardingWallpaperVm? wallpaper,
      FirstWallpaperStatus status = FirstWallpaperStatus.idle,
    }) => OnboardingV2State.initial().copyWith(
      step: OnboardingV2Step.firstWallpaper,
      wallpaperData: OnboardingWallpaperData(wallpaper: wallpaper, status: status),
    );
    const vm = OnboardingWallpaperVm(fullUrl: '', thumbnailUrl: '', sourceCategory: 'Nature');

    testWidgets('a picked wallpaper can be set now or later', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpPage(tester, const F4FirstWallpaperPage(), wall(wallpaper: vm));

        expect(find.text('Make it yours'), findsOneWidget);
        expect(find.text('Picked for your interest in Nature.'), findsOneWidget);
        await tester.tap(find.text('Set as wallpaper'));
        verify(() => bloc.add(const OnboardingV2Event.firstWallpaperActionRequested())).called(1);
        await tester.tap(find.text('Later'));
        verify(() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued())).called(1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS saves to Photos', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpPage(tester, const F4FirstWallpaperPage(), wall(wallpaper: vm));

        expect(find.text('Save to Photos'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('no wallpaper falls back to the art and a plain Continue', (tester) async {
      await pumpPage(tester, const F4FirstWallpaperPage(), wall());

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      await tester.tap(find.text('Continue'));
      verify(() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued())).called(1);
    });

    testWidgets('the action shows a busy button', (tester) async {
      await pumpPage(tester, const F4FirstWallpaperPage(), wall(wallpaper: vm, status: FirstWallpaperStatus.loading));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('small screens and large text', () {
    final states = <String, (Widget, OnboardingV2State)>{
      'interests': (
        const F1InterestsPage(),
        interests(available: <String>['Nature', 'Space', 'Anime', 'Cars', 'Minimal', 'Abstract']),
      ),
      'ai generate': (
        const F3AiGeneratePage(),
        OnboardingV2State.initial().copyWith(
          step: OnboardingV2Step.aiGenerate,
          aiData: const OnboardingAiData(
            prompt: 'a misty mountain range at dawn with a calm lake',
            stylePreset: AiStylePreset.nature,
            status: AiGenerateStatus.failure,
          ),
        ),
      ),
      'first wallpaper': (
        const F4FirstWallpaperPage(),
        OnboardingV2State.initial().copyWith(
          step: OnboardingV2Step.firstWallpaper,
          wallpaperData: const OnboardingWallpaperData(
            wallpaper: OnboardingWallpaperVm(fullUrl: '', thumbnailUrl: '', sourceCategory: 'Nature'),
            status: FirstWallpaperStatus.idle,
          ),
        ),
      ),
    };

    for (final entry in states.entries) {
      testWidgets('${entry.key} lays out without overflow at 360 by 640 and 1.3x text', (tester) async {
        await pumpPage(tester, entry.value.$1, entry.value.$2, width: 360, height: 640, textScale: 1.3);
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('real compact and landscape viewports', () {
    final cases = <String, (double, double, double)>{
      'compact 2x': (320, 568, 2),
      'compact 3x': (320, 568, 3),
      '390x844 3x': (390, 844, 3),
      'landscape 2x': (844, 390, 2),
      'landscape 3x': (844, 390, 3),
    };

    for (final entry in cases.entries) {
      testWidgets('F1-F4 primary actions stay reachable at ${entry.key}', (tester) async {
        final (width, height, textScale) = entry.value;
        const all = <String>['Nature', 'Space', 'Anime'];
        final creators = <OnboardingStarterCreatorEntity>[_creator(1), _creator(2), _creator(3)];
        final steps = <(Widget, OnboardingV2State, String)>[
          (const F1InterestsPage(), interests(available: all, selected: all), 'Continue'),
          (
            const F2StarterPackPage(),
            OnboardingV2State.initial().copyWith(
              step: OnboardingV2Step.starterPack,
              loadStatus: LoadStatus.success,
              starterPackData: OnboardingStarterPackData(
                creators: creators,
                selectedEmails: creators.map((creator) => creator.email).toSet(),
              ),
            ),
            'Continue',
          ),
          (
            const F3AiGeneratePage(),
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
            const F4FirstWallpaperPage(),
            OnboardingV2State.initial().copyWith(step: OnboardingV2Step.firstWallpaper),
            'Continue',
          ),
        ];

        for (final (page, state, label) in steps) {
          await pumpPage(tester, page, state, width: width, height: height, textScale: textScale);
          final Finder action = find.text(label);
          await tester.ensureVisible(action);
          expect(tester.getRect(action).overlaps(Offset.zero & Size(width, height)), isTrue);
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow in ${page.runtimeType} at ${width}x$height with $textScale text',
          );
        }
      });
    }
  });
}
