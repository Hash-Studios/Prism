import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/day_night_support.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_session_listener.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

class _MockDayNightBloc extends MockBloc<DayNightEvent, DayNightState> implements DayNightBloc {}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const DayNightEvent.proLapseAcknowledged());
  });

  setUp(() {
    dayNightSupportedOverride = true;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = profileUser(id: 'account-a');
    CoinsService.instance.resetSession();
  });
  tearDown(() {
    dayNightSupportedOverride = null;
    app_state.prismUser = profileUser(id: 'account-a');
    CoinsService.instance.resetSession();
    AnalyticsRuntime.reset();
  });

  testWidgets('a lapsed Pro plan shows one toast and acknowledges it', (tester) async {
    final _MockDayNightBloc dayNightBloc = _MockDayNightBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final StreamController<DayNightState> states = StreamController<DayNightState>();
    when(() => dayNightBloc.state).thenReturn(DayNightState.initial());
    whenListen(dayNightBloc, states.stream, initialState: DayNightState.initial());
    whenListen(sessionBloc, const Stream<SessionState>.empty(), initialState: SessionState.initial());
    toasts.overlayResolver = null;
    addTearDown(() async {
      toasts.overlayResolver = null;
      await states.close();
    });

    await tester.pumpWidget(_listenerTree(dayNightBloc, sessionBloc));
    toasts.overlayResolver = () => tester.state<OverlayState>(find.byType(Overlay).first);

    final DayNightState lapsed = DayNightState(pair: DayNightPair(), proLapsed: true);
    when(() => dayNightBloc.state).thenReturn(lapsed);
    states.add(lapsed);
    await tester.pump();
    await tester.pump();

    expect(find.text('Day and night is off because your Prism Pro plan or pass ended.'), findsOneWidget);
    verify(() => dayNightBloc.add(const DayNightEvent.proLapseAcknowledged())).called(1);

    // Let the toast release its overlay entry before the next test replaces the app.
    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('does not send day and night events when the platform is not supported', (tester) async {
    dayNightSupportedOverride = false;
    final _MockDayNightBloc dayNightBloc = _MockDayNightBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final StreamController<DayNightState> states = StreamController<DayNightState>();
    final StreamController<SessionState> sessions = StreamController<SessionState>();
    when(() => dayNightBloc.state).thenReturn(DayNightState.initial());
    whenListen(dayNightBloc, states.stream, initialState: DayNightState.initial());
    whenListen(sessionBloc, sessions.stream, initialState: SessionState.initial());
    addTearDown(() async {
      toasts.overlayResolver = null;
      await states.close();
      await sessions.close();
    });

    await tester.pumpWidget(_listenerTree(dayNightBloc, sessionBloc));
    toasts.overlayResolver = () => tester.state<OverlayState>(find.byType(Overlay).first);

    const SessionState signedIn = SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: 'account-a', loggedIn: true, premium: true, subscriptionTier: 'pro'),
    );
    when(() => sessionBloc.state).thenReturn(signedIn);
    sessions.add(signedIn);
    final DayNightState lapsed = DayNightState(pair: DayNightPair(), proLapsed: true);
    when(() => dayNightBloc.state).thenReturn(lapsed);
    states.add(lapsed);
    await tester.pump();
    await tester.pump();

    expect(find.text('Day and night is off because your Prism Pro plan or pass ended.'), findsNothing);
    verifyNever(() => dayNightBloc.add(any()));
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

Widget _listenerTree(DayNightBloc dayNightBloc, SessionBloc sessionBloc) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<DayNightBloc>.value(value: dayNightBloc),
      BlocProvider<SessionBloc>.value(value: sessionBloc),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DayNightSessionListener(child: SizedBox()),
    ),
  );
}
