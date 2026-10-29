import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/wall_requests/biz/wall_request_sheet_cubit.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';

class _MockSheetCubit extends MockCubit<WallRequestSheetState> implements WallRequestSheetCubit {}

WallRequest _request({bool mine = false, bool voted = false}) => WallRequest(
  id: 'r1',
  text: 'dark minimal mountains',
  tags: const <String>['Minimal', 'dreamy'],
  voteCount: 4,
  status: WallRequestStatus.open,
  createdAt: DateTime(2026, 10, 28),
  requesterName: 'Ana',
  requesterPhoto: '',
  mine: mine,
  voted: voted,
  hidden: false,
);

void main() {
  late _MockSheetCubit cubit;

  void stub(WallRequestSheetState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<WallRequestSheetState>.empty(), initialState: state);
  }

  setUp(() {
    cubit = _MockSheetCubit();
    when(() => cubit.upvoteInstead()).thenAnswer((_) async {});
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
  });

  tearDown(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  /// Opens the sheet from a button, as the app does, and lets it finish its entrance.
  Future<void> openSheet(WidgetTester tester, {Locale? locale, String initialText = ''}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  unawaited(
                    showPrismSheet<void>(
                      context,
                      builder: (_) => BlocProvider<WallRequestSheetCubit>.value(
                        value: cubit,
                        child: WallRequestSheetBody(
                          source: WallRequestSourceValue.requestsPage,
                          initialText: initialText,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.ancestor(of: find.text('Request it'), matching: find.byType(FilledButton)));

  testWidgets('a close open request offers Upvote this instead and Request mine anyway', (tester) async {
    stub(WallRequestSheetDuplicate(_request(), exact: false));
    await openSheet(tester);

    expect(find.text('Someone asked for this already'), findsOneWidget);
    expect(find.text('Upvote this instead'), findsOneWidget);
    expect(find.text('Request mine anyway'), findsOneWidget);
  });

  testWidgets('an exact duplicate hides Request mine anyway', (tester) async {
    stub(WallRequestSheetDuplicate(_request(), exact: true));
    await openSheet(tester);

    expect(find.text('Upvote this instead'), findsOneWidget);
    expect(find.text('Request mine anyway'), findsNothing);
  });

  testWidgets('the user own duplicate has no upvote button', (tester) async {
    stub(WallRequestSheetDuplicate(_request(mine: true), exact: false));
    await openSheet(tester);

    expect(find.text('You asked for this already'), findsOneWidget);
    expect(find.text('Upvote this instead'), findsNothing);
    expect(find.text('Request mine anyway'), findsNothing);
  });

  testWidgets('tapping Upvote this instead calls upvoteInstead', (tester) async {
    stub(WallRequestSheetDuplicate(_request(), exact: false));
    await openSheet(tester);

    await tester.tap(find.text('Upvote this instead'));
    await tester.pump();

    verify(() => cubit.upvoteInstead()).called(1);
  });

  const List<(Locale, String)> accountAgeCopy = <(Locale, String)>[
    (Locale('en'), "Your account can request walls and vote once it's 10 days old."),
    (Locale('de'), 'Dein Konto kann Wünsche senden und abstimmen, sobald es 10 Tage alt ist.'),
    (Locale('es'), 'Tu cuenta podrá hacer solicitudes y votar cuando tenga 10 días.'),
    (Locale('hi'), 'आपका खाता 10 दिन पुराना होने पर अनुरोध और वोट कर सकेगा।'),
    (Locale('id'), 'Akun Anda bisa membuat permintaan dan memberi suara setelah berumur 10 hari.'),
    (Locale('pt'), 'Sua conta poderá fazer pedidos e votar quando tiver 10 dias.'),
    (Locale('pt', 'BR'), 'Sua conta poderá fazer pedidos e votar quando tiver 10 dias.'),
  ];
  for (final (Locale locale, String copy) in accountAgeCopy) {
    for (final bool duplicate in <bool>[false, true]) {
      testWidgets('$locale shows the account-age error on the ${duplicate ? 'duplicate' : 'form'} sheet', (
        tester,
      ) async {
        stub(
          duplicate
              ? WallRequestSheetDuplicate(_request(), exact: false, error: WallRequestError.accountTooNew)
              : const WallRequestSheetEditing(error: WallRequestError.accountTooNew),
        );
        await openSheet(tester, locale: locale);

        expect(find.text(copy), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the submit button needs at least 3 characters', (tester) async {
    stub(const WallRequestSheetEditing());
    await openSheet(tester);

    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('a search query longer than 80 characters is cut to 80', (tester) async {
    stub(const WallRequestSheetEditing());
    await openSheet(tester, initialText: '  ${'a' * 100}  ');

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'a' * 80);
  });

  testWidgets('a fourth tag cannot be selected after three', (tester) async {
    stub(const WallRequestSheetEditing());
    await openSheet(tester);

    for (final String tag in <String>['Nature', 'Dark', 'Space']) {
      await tester.ensureVisible(find.text(tag));
      await tester.tap(find.text(tag));
      await tester.pump();
    }

    await tester.ensureVisible(find.text('Neon'));
    expect(tester.widget<PrismChip>(find.widgetWithText(PrismChip, 'Neon')).onTap, isNull);
    expect(tester.widget<PrismChip>(find.widgetWithText(PrismChip, 'Dark')).selected, isTrue);
  });

  for (final bool upvoted in <bool>[false, true]) {
    testWidgets('the root request sheet returns ${upvoted ? 'an upvote' : 'a creation'} to a nested caller', (
      tester,
    ) async {
      final GlobalKey<NavigatorState> root = GlobalKey<NavigatorState>();
      final GlobalKey<NavigatorState> nested = GlobalKey<NavigatorState>();
      final StreamController<WallRequestSheetState> states = StreamController<WallRequestSheetState>();
      whenListen(cubit, states.stream, initialState: const WallRequestSheetEditing());
      when(() => cubit.close()).thenAnswer((_) async {});
      getIt.registerFactory<WallRequestSheetCubit>(() => cubit);
      AnalyticsRuntime.instance = FakeAppAnalytics();
      toasts.overlayResolver = () => root.currentState?.overlay;
      addTearDown(() async {
        toasts.overlayResolver = null;
        AnalyticsRuntime.reset();
        await states.close();
        await getIt.reset();
      });
      WallRequest? returned;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: root,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Navigator(
            key: nested,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (BuildContext context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    returned = await showWallRequestSheet(
                      context,
                      source: WallRequestSourceValue.search,
                      initialText: 'dark mountains',
                    );
                  },
                  child: const Text('nested caller'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('nested caller'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(root.currentState!.canPop(), isTrue);
      expect(nested.currentState!.canPop(), isFalse);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'dark mountains');

      final WallRequest request = _request(voted: upvoted);
      states.add(WallRequestSheetDone(request, upvoted: upvoted));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(returned, same(request));
      expect(root.currentState!.canPop(), isFalse);
      expect(nested.currentState!.canPop(), isFalse);
      expect(find.text('nested caller'), findsOneWidget);
      final String message = upvoted
          ? "Upvoted. We'll tell you when it's filled."
          : "Request sent. We'll tell you when it's filled.";
      expect(find.text(message), findsOneWidget);
      verify(() => cubit.close()).called(1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }
}
