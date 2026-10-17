import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/draw/biz/bloc/draw_bloc.j.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:Prism/features/draw/views/pages/draw_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<DrawEvent, DrawState> implements DrawBloc {}

DrawEntity _draw({int tickets = 24, int participants = 9}) => DrawEntity(
  weekKey: '2026-W42',
  status: 'open',
  closesAt: DateTime.now().add(const Duration(days: 2, hours: 3, minutes: 30)),
  tickets: tickets,
  participants: participants,
  prizeProMonths: 1,
  prizeItemId: 'frame_prism',
);

void main() {
  late _MockBloc bloc;

  setUpAll(() => registerFallbackValue(const DrawEvent.started()));

  setUp(() {
    bloc = _MockBloc();
    EconomyConfig.current = const EconomyConfig(flags: EconomyFlags(drawEnabled: true));
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  tearDown(() {
    EconomyConfig.resetForTest();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pumpPage(WidgetTester tester, DrawState state) {
    whenListen(bloc, const Stream<DrawState>.empty(), initialState: state);
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<DrawBloc>.value(value: bloc, child: const DrawPage()),
      ),
    );
  }

  DrawState loaded({int myTickets = 2, DrawEntity? lastWinner, DrawEntity? draw}) => DrawState.initial().copyWith(
    status: LoadStatus.success,
    draw: draw ?? _draw(),
    myTickets: myTickets,
    lastWinner: lastWinner,
  );

  testWidgets('is hidden while the draw flag is off', (tester) async {
    EconomyConfig.current = EconomyConfig.defaults;

    await pumpPage(tester, loaded());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('The Draw is not open yet.'), findsOneWidget);
    expect(find.textContaining('Buy a ticket'), findsNothing);
  });

  testWidgets('shows the prize, the pot, the countdown, my tickets and the odds', (tester) async {
    await pumpPage(tester, loaded());

    expect(find.text('Prism Draw'), findsOneWidget);
    expect(find.text('1 month of Pro + the Prism frame'), findsOneWidget);
    expect(find.text('24 tickets from 9 people'), findsOneWidget);
    expect(find.textContaining('Closes in 2d '), findsOneWidget);
    expect(find.text('Your tickets: 2 of 5'), findsOneWidget);
    expect(find.text('Your chance: 2/24'), findsOneWidget);
    expect(find.text('Official rules'), findsOneWidget);
  });

  testWidgets('the buy button sends a ticket request', (tester) async {
    await pumpPage(tester, loaded());

    await tester.tap(find.textContaining('Buy a ticket'));

    verify(() => bloc.add(const DrawEvent.ticketRequested())).called(1);
  });

  testWidgets('five tickets disable the button', (tester) async {
    await pumpPage(tester, loaded(myTickets: 5));

    await tester.tap(find.textContaining('Buy a ticket'), warnIfMissed: false);

    expect(find.text('Your tickets: 5 of 5'), findsOneWidget);
    expect(find.text('You hold all 5 tickets this week.'), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('Pro members see why they cannot buy', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
    await pumpPage(tester, loaded());

    await tester.tap(find.textContaining('Buy a ticket'), warnIfMissed: false);

    expect(find.text('Pro members are not eligible'), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('shows the last winner', (tester) async {
    final DrawEntity settled = _draw().copyWith(status: 'settled', winnerName: 'Ana');

    await pumpPage(tester, loaded(lastWinner: settled));

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Last winner'), findsOneWidget);
  });

  testWidgets('odds never show fewer tickets in the pot than mine', (tester) async {
    await pumpPage(tester, loaded(myTickets: 3, draw: _draw(tickets: 1)));

    expect(find.text('Your chance: 3/3'), findsOneWidget);
  });

  testWidgets('shows a retry state when the load fails', (tester) async {
    await pumpPage(tester, DrawState.initial().copyWith(status: LoadStatus.failure));

    expect(find.text("Couldn't load the Draw"), findsOneWidget);
  });

  test('drawTimeLeft counts days and hours, then hours and minutes', () {
    final DateTime now = DateTime.utc(2026, 10, 17, 20);
    expect(drawTimeLeft(DateTime.utc(2026, 10, 19), now), '1d 4h');
    expect(drawTimeLeft(DateTime.utc(2026, 10, 18, 1, 20), now), '5h 20m');
    expect(drawTimeLeft(DateTime.utc(2026, 10, 17), now), '0m');
  });
}
