import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/creator_fund/biz/bloc/creator_fund_bloc.j.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';
import 'package:Prism/features/creator_fund/views/widgets/creator_fund_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../support/fake_app_analytics.dart';

class MockCreatorFundBloc extends MockBloc<CreatorFundEvent, CreatorFundState> implements CreatorFundBloc {}

const _week = '2026-W46';

Widget _app(CreatorFundBloc bloc, {double textScale = 1, bool rtl = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  ),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: BlocProvider<CreatorFundBloc>.value(value: bloc, child: const CreatorFundRow()),
    ),
  ),
);

void main() {
  late FakeAppAnalytics analytics;
  late MockCreatorFundBloc bloc;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);
    bloc = MockCreatorFundBloc();
  });

  void stub(CreatorFundState state) => when(() => bloc.state).thenReturn(state);

  CreatorFundState loaded(CreatorFundStatus status) => CreatorFundState(status: status);

  testWidgets('paid shows coins and exact percent', (tester) async {
    stub(loaded(const CreatorFundPaid(week: _week, coins: 120, shareBps: 325)));
    await tester.pumpWidget(_app(bloc));

    expect(find.text('You earned 120 coins last week'), findsOneWidget);
    expect(find.text('That is 3.3% of the fund.'), findsOneWidget);
    expect(find.text('Creator fund'), findsOneWidget);
  });

  testWidgets('notQualified fewUsers shows the exact sentence', (tester) async {
    stub(
      loaded(
        const CreatorFundNotQualified(
          week: _week,
          reason: CreatorFundReason.fewUsers,
          distinctUsers: 3,
          minDistinctUsers: 5,
          minPayout: 1,
        ),
      ),
    );
    await tester.pumpWidget(_app(bloc));

    expect(find.text('Last week, 3 people engaged with your walls. You need at least 5 to qualify.'), findsOneWidget);
  });

  testWidgets('off shows the off line', (tester) async {
    stub(loaded(const CreatorFundOff(week: _week)));
    await tester.pumpWidget(_app(bloc));

    expect(find.text('The Creator fund is not running right now.'), findsOneWidget);
  });

  testWidgets('paid stays free of overflow at 2x text scale', (tester) async {
    stub(loaded(const CreatorFundPaid(week: _week, coins: 120, shareBps: 325)));
    await tester.pumpWidget(_app(bloc, textScale: 2));

    expect(tester.takeException(), isNull);
    expect(find.text('You earned 120 coins last week'), findsOneWidget);
  });

  testWidgets('paid renders in RTL with the title in the semantics label', (tester) async {
    stub(loaded(const CreatorFundPaid(week: _week, coins: 120, shareBps: 325)));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(bloc, rtl: true));

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel(RegExp(r'^Creator fund\. You earned 120 coins last week\. That is 3\.3% of the fund\.')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('failed shows the error and retry re-adds load', (tester) async {
    stub(const CreatorFundState(failed: true));
    await tester.pumpWidget(_app(bloc));

    expect(find.text('Unable to load the Creator fund. Check your connection and try again.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pump();

    verify(() => bloc.add(const CreatorFundEvent.load())).called(1);
  });

  testWidgets('tracks the viewed event once across rebuilds', (tester) async {
    whenListen(
      bloc,
      Stream<CreatorFundState>.fromIterable([
        loaded(const CreatorFundPaid(week: _week, coins: 120, shareBps: 325)),
        loaded(const CreatorFundPaid(week: _week, coins: 130, shareBps: 325)),
      ]),
      initialState: const CreatorFundState(loading: true),
    );
    await tester.pumpWidget(_app(bloc));
    await tester.pump();
    await tester.pump();

    expect(analytics.events.where((event) => event.eventName == 'creator_fund_viewed'), hasLength(1));
  });
}
