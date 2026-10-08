import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f1_interests_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f2_starter_pack_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_scrollable_canvas.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

Widget _app({required Widget child, double textScale = 1.0}) => MaterialApp(
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: app!,
  ),
  home: Scaffold(body: child),
);

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => registerFallbackValue(const OnboardingV2Event.started()));

  group('OnboardingFrame', () {
    testWidgets('a landscape tablet keeps a column no wider than the content cap', (tester) async {
      await _setSurface(tester, const Size(1280, 800));
      double? seenSx;
      double? seenSy;
      await tester.pumpWidget(
        _app(
          child: OnboardingFrame(
            builder: (context, sx, sy) {
              seenSx = sx;
              seenSy = sy;
              return const SizedBox.expand(key: Key('content'));
            },
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('content'))).width,
        lessThanOrEqualTo(OnboardingLayout.maxContentWidth),
      );
      expect(seenSx, lessThanOrEqualTo(seenSy!));
    });

    testWidgets('a design-size phone is not rescaled', (tester) async {
      await _setSurface(tester, const Size(393, 852));
      double? seenSx;
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
              child: OnboardingFrame(
                builder: (context, sx, sy) {
                  seenSx = sx;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      expect(seenSx, closeTo(1, 0.001));
    });
  });

  group('OnboardingScrollableCanvas', () {
    Future<void> pumpCanvas(WidgetTester tester, {required Size size, required double textScale}) async {
      await _setSurface(tester, size);
      await tester.pumpWidget(
        _app(
          textScale: textScale,
          child: const OnboardingScrollableCanvas(
            children: [
              SizedBox.expand(key: Key('page')),
              Align(alignment: Alignment.bottomCenter, child: Text('end')),
            ],
          ),
        ),
      );
    }

    testWidgets('a short screen scrolls and the bottom of the layout can be reached', (tester) async {
      await pumpCanvas(tester, size: const Size(360, 560), textScale: 1);

      expect(tester.getSize(find.byKey(const Key('page'))).height, greaterThan(560));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pump();
      expect(tester.getBottomLeft(find.text('end')).dy, lessThanOrEqualTo(560));
    });

    testWidgets('1.3x text on a normal phone gets a taller canvas that scrolls', (tester) async {
      await pumpCanvas(tester, size: const Size(393, 852), textScale: 1.3);

      expect(tester.getSize(find.byKey(const Key('page'))).height, greaterThan(852));
    });

    testWidgets('a tall phone at normal text does not scroll', (tester) async {
      await pumpCanvas(tester, size: const Size(393, 852), textScale: 1);

      expect(tester.getSize(find.byKey(const Key('page'))).height, 852);
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
      await _setSurface(tester, const Size(320, 480));
      when(() => bloc.state).thenReturn(state);
      whenListen(bloc, const Stream<OnboardingV2State>.empty(), initialState: state);
      await tester.pumpWidget(
        _app(
          textScale: 1.3,
          child: BlocProvider<OnboardingV2Bloc>.value(value: bloc, child: page),
        ),
      );
      await tester.pump();
    }

    testWidgets('interests lay out without overflow and Skip sends interestsSkipped', (tester) async {
      await pumpPage(tester, const F1InterestsPage(), stateWith(categories: <String>['Nature', 'Anime', 'Minimal']));

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('skip'));
      verify(() => bloc.add(const OnboardingV2Event.interestsSkipped())).called(1);
    });

    testWidgets('an empty interests list offers Try again and Skip instead of a spinner', (tester) async {
      await pumpPage(tester, const F1InterestsPage(), stateWith());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Try again'));
      verify(() => bloc.add(const OnboardingV2Event.loadRetried())).called(1);
      expect(find.text('skip'), findsOneWidget);
    });

    testWidgets('a list that is still loading shows the spinner', (tester) async {
      await pumpPage(tester, const F1InterestsPage(), stateWith(loadStatus: LoadStatus.loading));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('an empty starter pack offers Try again and Skip sends starterPackSkipped', (tester) async {
      await pumpPage(tester, const F2StarterPackPage(), stateWith().copyWith(step: OnboardingV2Step.starterPack));

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Try again'));
      verify(() => bloc.add(const OnboardingV2Event.loadRetried())).called(1);
      await tester.tap(find.text('skip'));
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
