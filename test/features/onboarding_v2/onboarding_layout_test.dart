import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f1_interests_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f2_starter_pack_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

Widget _app({required Widget child, double textScale = 1.0}) => MaterialApp(
  theme: prismDarkThemes.first.theme,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: app!,
  ),
  home: Scaffold(body: child),
);

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => registerFallbackValue(const OnboardingV2Event.started()));

  group('OnboardingFrame', () {
    Widget frame() => OnboardingFrame(
      title: 'A title',
      body: 'One line of body text.',
      primaryLabel: 'Continue',
      onPrimary: () {},
      child: const SizedBox.expand(key: Key('content')),
    );

    testWidgets('a landscape tablet keeps a column no wider than the content cap', (tester) async {
      _setSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(child: frame()));

      expect(
        tester.getSize(find.byKey(const Key('content'))).width,
        lessThanOrEqualTo(OnboardingLayout.maxContentWidth),
      );
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Continue')).width,
        lessThan(OnboardingLayout.maxContentWidth),
      );
    });

    testWidgets('the column is centred on a wide screen', (tester) async {
      _setSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(child: frame()));

      expect(tester.getCenter(find.byKey(const Key('content'))).dx, closeTo(640, 0.5));
    });

    testWidgets('a phone is not narrowed', (tester) async {
      _setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(_app(child: frame()));

      expect(tester.getSize(find.byKey(const Key('content'))).width, 390);
    });
  });

  group('step pages on a small surface at 1.3x text', () {
    late _MockOnboardingBloc bloc;

    OnboardingV2State stateWith({
      List<String> categories = const <String>[],
      LoadStatus loadStatus = LoadStatus.success,
    }) => OnboardingV2State.initial().copyWith(
      step: OnboardingV2Step.interests,
      loadStatus: loadStatus,
      interestsData: OnboardingInterestsData(
        available: categories,
        selected: const <String>[],
        categoryImages: const <String, String>{},
      ),
    );

    setUp(() => bloc = _MockOnboardingBloc());

    Future<void> pumpPage(WidgetTester tester, Widget page, OnboardingV2State state) async {
      _setSurface(tester, const Size(320, 480));
      when(() => bloc.state).thenReturn(state);
      whenListen(bloc, const Stream<OnboardingV2State>.empty(), initialState: state);
      await tester.pumpWidget(
        _app(
          textScale: 1.3,
          child: BlocProvider<OnboardingV2Bloc>.value(value: bloc, child: page),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('interests lay out without overflow and Skip sends interestsSkipped', (tester) async {
      await pumpPage(tester, const F1InterestsPage(), stateWith(categories: <String>['Nature', 'Anime', 'Minimal']));

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Skip'));
      verify(() => bloc.add(const OnboardingV2Event.interestsSkipped())).called(1);
    });

    testWidgets('an empty interests list offers Try again and Skip instead of a spinner', (tester) async {
      await pumpPage(tester, const F1InterestsPage(), stateWith());

      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Try again'));
      verify(() => bloc.add(const OnboardingV2Event.loadRetried())).called(1);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('an empty starter pack offers Try again and Skip sends starterPackSkipped', (tester) async {
      await pumpPage(tester, const F2StarterPackPage(), stateWith().copyWith(step: OnboardingV2Step.starterPack));

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Try again'));
      verify(() => bloc.add(const OnboardingV2Event.loadRetried())).called(1);
      await tester.tap(find.text('Skip'));
      verify(() => bloc.add(const OnboardingV2Event.starterPackSkipped())).called(1);
    });
  });

  testWidgets('the primary button label fits a narrow button at 1.3x text', (tester) async {
    await tester.pumpWidget(
      _app(
        textScale: 1.3,
        child: Center(
          child: SizedBox(
            width: 180,
            height: 48,
            child: OnboardingPrimaryButton(label: 'Continue with Apple', icon: Icons.apple, onPressed: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
