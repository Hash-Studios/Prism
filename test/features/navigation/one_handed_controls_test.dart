import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

class _FakeTabsRouter extends ChangeNotifier implements TabsRouter {
  @override
  int get activeIndex => 0;

  @override
  StackRouter? stackRouterOfIndex(int index) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestRouter extends RootStackRouter {
  _TestRouter(this.home);

  final Widget home;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo('Home', builder: (_) => home),
    ),
    AutoRoute(
      path: '/notifications',
      page: PageInfo(NotificationRoute.name, builder: (_) => const SizedBox.shrink()),
    ),
    AutoRoute(
      path: '/profile',
      page: PageInfo(ProfileRoute.name, builder: (_) => const SizedBox.shrink()),
    ),
  ];
}

_MockNotificationsBloc _bloc(int unread) {
  final _MockNotificationsBloc bloc = _MockNotificationsBloc();
  when(() => bloc.state).thenReturn(InAppNotificationsState.initial().copyWith(unreadCount: unread));
  return bloc;
}

ValueNotifier<LayoutPrefs> _prefs(WidgetTester tester, {required bool oneHanded}) {
  final ValueNotifier<LayoutPrefs> prefs = ValueNotifier<LayoutPrefs>(LayoutPrefs(oneHanded: oneHanded));
  addTearDown(prefs.dispose);
  return prefs;
}

Future<_TestRouter> _pump(
  WidgetTester tester, {
  required double width,
  required InAppNotificationsBloc bloc,
  required ValueNotifier<LayoutPrefs> prefs,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final _TestRouter router = _TestRouter(
    Directionality(
      textDirection: direction,
      child: TabsRouterScope(
        controller: _FakeTabsRouter(),
        stateHash: 0,
        child: const Scaffold(
          body: BottomBar(
            child: Align(alignment: Alignment.topCenter, child: PrismTopAppBar()),
          ),
        ),
      ),
    ),
  );

  await tester.pumpWidget(
    LayoutPrefsScope(
      prefs: prefs,
      child: BlocProvider<InAppNotificationsBloc>.value(
        value: bloc,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: prismLightThemes.first.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          routerConfig: router.config(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// A widget test with semantics on for the whole body, so finders can use semantics labels.
void _semanticsTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      handle.dispose();
    }
  });
}

void main() {
  late FakeAppAnalytics analytics;
  late PrismUsersV2 previousUser;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    previousUser = app_state.prismUser;
    app_state.prismUser = profileUser(profilePhoto: '', username: 'mira');
  });
  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = previousUser;
  });

  _semanticsTest('off: the top bar shows the avatar and the bell, the bottom row shows neither', (tester) async {
    await _pump(tester, width: 390, bloc: _bloc(2), prefs: _prefs(tester, oneHanded: false));

    expect(
      find.descendant(of: find.byType(PrismTopAppBar), matching: find.bySemanticsLabel('Your profile')),
      findsOneWidget,
    );
    expect(find.descendant(of: find.byType(PrismTopAppBar), matching: find.byTooltip('Notifications')), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Profile and notifications'), findsNothing);
    expect(find.bySemanticsLabel('Your profile'), findsOneWidget);
  });

  _semanticsTest('on at 390: the top bar keeps only the wordmark, the bottom row holds the avatar and the bell', (
    tester,
  ) async {
    await _pump(tester, width: 390, bloc: _bloc(0), prefs: _prefs(tester, oneHanded: true));

    expect(
      find.descendant(of: find.byType(PrismTopAppBar), matching: find.bySemanticsLabel('Your profile')),
      findsNothing,
    );
    expect(find.descendant(of: find.byType(PrismTopAppBar), matching: find.byTooltip('Notifications')), findsNothing);
    expect(find.bySemanticsLabel('Your profile'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);

    final double avatarX = tester.getCenter(find.bySemanticsLabel('Your profile')).dx;
    final double pillX = tester.getCenter(find.byType(PrismBottomNav)).dx;
    final double createX = tester.getCenter(find.byType(PrismFab)).dx;
    final double bellX = tester.getCenter(find.byTooltip('Notifications')).dx;
    expect(avatarX, lessThan(pillX));
    expect(bellX, greaterThan(createX));
  });

  _semanticsTest('on at 390 with unread items, the bottom bell has the unread hint', (tester) async {
    await _pump(tester, width: 390, bloc: _bloc(2), prefs: _prefs(tester, oneHanded: true));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Open notifications')),
      isSemantics(isButton: true, hint: 'Has unread items'),
    );
  });

  _semanticsTest('on at 390 with no unread items, the bottom bell has no hint', (tester) async {
    await _pump(tester, width: 390, bloc: _bloc(0), prefs: _prefs(tester, oneHanded: true));

    expect(tester.getSemantics(find.bySemanticsLabel('Open notifications')).hint, isEmpty);
  });

  _semanticsTest('the unread dot follows the bloc: a state with no unread items clears the hint', (tester) async {
    final _MockNotificationsBloc bloc = _MockNotificationsBloc();
    final StreamController<InAppNotificationsState> states = StreamController<InAppNotificationsState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: InAppNotificationsState.initial().copyWith(unreadCount: 2));
    await _pump(tester, width: 390, bloc: bloc, prefs: _prefs(tester, oneHanded: true));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Open notifications')),
      isSemantics(isButton: true, hint: 'Has unread items'),
    );

    states.add(InAppNotificationsState.initial().copyWith(unreadCount: 0));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.bySemanticsLabel('Open notifications')).hint, isEmpty);
  });

  _semanticsTest('on at 390: the bottom bell pushes the notifications route and tracks source bottom', (tester) async {
    final _TestRouter router = await _pump(tester, width: 390, bloc: _bloc(0), prefs: _prefs(tester, oneHanded: true));

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(router.stack.last.name, NotificationRoute.name);
    final NotificationsOpenedEvent event = analytics.events.whereType<NotificationsOpenedEvent>().single;
    expect(event.source, NotificationsEntrySourceValue.bottom);
  });

  _semanticsTest('off: the top bell tracks source top', (tester) async {
    final _TestRouter router = await _pump(tester, width: 390, bloc: _bloc(0), prefs: _prefs(tester, oneHanded: false));

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(router.stack.last.name, NotificationRoute.name);
    final NotificationsOpenedEvent event = analytics.events.whereType<NotificationsOpenedEvent>().single;
    expect(event.source, NotificationsEntrySourceValue.top);
  });

  _semanticsTest('on at 390: the bottom avatar pushes the profile route', (tester) async {
    final _TestRouter router = await _pump(tester, width: 390, bloc: _bloc(0), prefs: _prefs(tester, oneHanded: true));

    await tester.tap(find.bySemanticsLabel('Your profile'));
    await tester.pumpAndSettle();

    expect(router.stack.last.name, ProfileRoute.name);
  });

  _semanticsTest('on at 320: the account button stands above create and nothing shrinks', (tester) async {
    await _pump(tester, width: 320, bloc: _bloc(2), prefs: _prefs(tester, oneHanded: true));

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Profile and notifications'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile and notifications'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsNothing);
    final Rect pill = tester.getRect(find.byType(PrismBottomNav));
    final Rect create = tester.getRect(find.byType(PrismFab));
    final Rect account = tester.getRect(find.byTooltip('Profile and notifications'));
    expect(pill.size, Size(PrismBottomNav.maxLength, 56));
    expect(create.size, const Size(56, 56));
    expect(account.size, const Size(44, 44));
    expect(account.center.dx, create.center.dx);
    expect(account.bottom, lessThanOrEqualTo(create.top));
    expect(pill.left, greaterThanOrEqualTo(0));
    expect(create.right, lessThanOrEqualTo(320));
  });

  _semanticsTest('on at 360: the account button sits in the row before the pill at full size', (tester) async {
    await _pump(tester, width: 360, bloc: _bloc(2), prefs: _prefs(tester, oneHanded: true));

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Notifications'), findsNothing);
    final Rect pill = tester.getRect(find.byType(PrismBottomNav));
    final Rect account = tester.getRect(find.byTooltip('Profile and notifications'));
    expect(pill.size, Size(PrismBottomNav.maxLength, 56));
    expect(account.size, const Size(44, 44));
    expect(account.right, lessThanOrEqualTo(pill.left));
    expect(account.center.dy, pill.center.dy);
  });

  _semanticsTest('on at 320 with unread items: the account sheet lists the profile and the notifications', (
    tester,
  ) async {
    await _pump(tester, width: 320, bloc: _bloc(2), prefs: _prefs(tester, oneHanded: true));

    await tester.tap(find.byTooltip('Profile and notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Profile and notifications'), findsOneWidget);
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('2 unread'), findsOneWidget);
  });

  _semanticsTest('on at 320: the sheet notifications row pushes the notifications route and tracks source bottom', (
    tester,
  ) async {
    final _TestRouter router = await _pump(tester, width: 320, bloc: _bloc(2), prefs: _prefs(tester, oneHanded: true));

    await tester.tap(find.byTooltip('Profile and notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(router.stack.last.name, NotificationRoute.name);
    final NotificationsOpenedEvent event = analytics.events.whereType<NotificationsOpenedEvent>().single;
    expect(event.source, NotificationsEntrySourceValue.bottom);
  });

  _semanticsTest('on at 320: the sheet profile row pushes the profile route', (tester) async {
    final _TestRouter router = await _pump(tester, width: 320, bloc: _bloc(2), prefs: _prefs(tester, oneHanded: true));

    await tester.tap(find.byTooltip('Profile and notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your profile'));
    await tester.pumpAndSettle();

    expect(router.stack.last.name, ProfileRoute.name);
  });

  _semanticsTest('on at 390 with 2x text scale: no exception and the pill keeps its width', (tester) async {
    await _pump(tester, width: 390, bloc: _bloc(0), prefs: _prefs(tester, oneHanded: true), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PrismBottomNav)).width, PrismBottomNav.maxLength);
  });

  _semanticsTest('guest on at 390: the bottom avatar shows and pushes the profile route', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..profilePhoto = '';
    final _TestRouter router = await _pump(tester, width: 390, bloc: _bloc(0), prefs: _prefs(tester, oneHanded: true));

    expect(find.bySemanticsLabel('Your profile'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Your profile'));
    await tester.pumpAndSettle();

    expect(router.stack.last.name, ProfileRoute.name);
  });

  _semanticsTest('right to left on at 390: the avatar sits right of the pill and the bell left of the create button', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 390,
      bloc: _bloc(0),
      prefs: _prefs(tester, oneHanded: true),
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    final double avatarX = tester.getCenter(find.bySemanticsLabel('Your profile')).dx;
    final double pillX = tester.getCenter(find.byType(PrismBottomNav)).dx;
    final double createX = tester.getCenter(find.byType(PrismFab)).dx;
    final double bellX = tester.getCenter(find.byTooltip('Notifications')).dx;
    expect(avatarX, greaterThan(pillX));
    expect(bellX, lessThan(createX));
  });

  _semanticsTest('right to left on at 320: the account button stands above create, left of the pill', (tester) async {
    await _pump(
      tester,
      width: 320,
      bloc: _bloc(0),
      prefs: _prefs(tester, oneHanded: true),
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    final double accountX = tester.getCenter(find.byTooltip('Profile and notifications')).dx;
    final double createX = tester.getCenter(find.byType(PrismFab)).dx;
    final double pillX = tester.getCenter(find.byType(PrismBottomNav)).dx;
    expect(accountX, createX);
    expect(accountX, lessThan(pillX));
  });

  _semanticsTest('switching one-handed on live moves the bell from the top bar to the bottom row', (tester) async {
    final ValueNotifier<LayoutPrefs> prefs = _prefs(tester, oneHanded: false);
    await _pump(tester, width: 390, bloc: _bloc(0), prefs: prefs);

    expect(find.descendant(of: find.byType(PrismTopAppBar), matching: find.byTooltip('Notifications')), findsOneWidget);

    prefs.value = const LayoutPrefs(oneHanded: true);
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(PrismTopAppBar), matching: find.byTooltip('Notifications')), findsNothing);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.bySemanticsLabel('Your profile'), findsOneWidget);
  });
}
