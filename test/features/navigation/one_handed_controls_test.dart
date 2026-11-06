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
  double height = 700,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  double horizontalInset = 0,
  double? rightInset,
  GlobalKey<ScaffoldMessengerState>? messengerKey,
  Widget? content,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(left: horizontalInset, right: rightInset ?? horizontalInset, bottom: 34);
  tester.view.viewPadding = FakeViewPadding(left: horizontalInset, right: rightInset ?? horizontalInset, bottom: 34);
  addTearDown(tester.view.reset);

  final _TestRouter router = _TestRouter(
    Directionality(
      textDirection: direction,
      child: TabsRouterScope(
        controller: _FakeTabsRouter(),
        stateHash: 0,
        child: Material(
          child: BottomBar(
            child: content ?? const Align(alignment: Alignment.topCenter, child: PrismTopAppBar()),
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
          scaffoldMessengerKey: messengerKey,
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
    expect(pill.size, Size(PrismBottomNav.maxLength(labels: false), 56));
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
    expect(pill.size, Size(PrismBottomNav.maxLength(labels: false), 56));
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
    expect(tester.getSize(find.byType(PrismBottomNav)).width, PrismBottomNav.maxLength(labels: false));
  });

  for (final direction in TextDirection.values) {
    for (final (width, height, left, right) in <(double, double, double, double)>[
      (320, 700, 12, 12),
      for (final width in <double>[360, 375, 376, 390, 423, 424]) (width, 700, 20, 20),
      (700, 320, 44, 24),
    ]) {
      _semanticsTest(
        '$width x $height with $left/$right insets, 2x text and $direction keep controls and feedback clear',
        (tester) async {
          final messenger = GlobalKey<ScaffoldMessengerState>();
          await _pump(
            tester,
            width: width,
            height: height,
            horizontalInset: left,
            rightInset: right,
            bloc: _bloc(2),
            prefs: _prefs(tester, oneHanded: true),
            textScale: 2,
            direction: direction,
            messengerKey: messenger,
            content: const Scaffold(body: SizedBox.expand()),
          );

          expect(tester.takeException(), isNull);
          final Rect pill = tester.getRect(find.byType(PrismBottomNav));
          final Rect create = tester.getRect(find.byType(PrismFab));
          // Labels widen the pill to 264. They show only where the avatar, the bell and the labelled pill all fit.
          final bool labelled = width - left - right - 20 >= 116 + 264 + 4 + 44;
          expect(pill.size, Size(labelled ? 264 : 200, 56));
          expect(create.size, const Size(56, 56));
          expect(find.bySemanticsLabel('Upload').hitTestable(), findsOneWidget);
          final bool stacked = width - left - right < 336;
          final bool separateBell = width - left - right >= 384;
          final Finder account = find.byTooltip('Profile and notifications');
          final Finder profile = find.bySemanticsLabel('Your profile');
          final Finder bell = find.byTooltip('Notifications');
          final List<Rect> controls = [pill, create];
          double top = pill.top;
          if (separateBell) {
            expect(account, findsNothing);
            expect(profile.hitTestable(), findsOneWidget);
            expect(bell.hitTestable(), findsOneWidget);
            expect(tester.getSize(profile), const Size(44, 44));
            expect(tester.getSize(bell), const Size(44, 44));
            final Rect avatar = tester.getRect(profile);
            final Rect notifications = tester.getRect(bell);
            controls.addAll([avatar, notifications]);
            expect(direction == TextDirection.ltr ? avatar.right <= pill.left : avatar.left >= pill.right, isTrue);
            expect(
              direction == TextDirection.ltr ? notifications.left >= create.right : notifications.right <= create.left,
              isTrue,
            );
          } else {
            expect(bell, findsNothing);
            expect(profile, findsNothing);
            expect(account.hitTestable(), findsOneWidget);
            final Rect target = tester.getRect(account);
            expect(target.size, const Size(44, 44));
            controls.add(target);
            if (stacked) {
              expect(target.center.dx, create.center.dx);
              expect(target.bottom, closeTo(create.top - 8, 0.01));
              top = target.top;
            } else {
              expect(target.center.dy, pill.center.dy);
              expect(direction == TextDirection.ltr ? target.right <= pill.left : target.left >= pill.right, isTrue);
            }
          }
          for (final target in controls) {
            expect(target.left, greaterThanOrEqualTo(left + 10));
            expect(target.right, lessThanOrEqualTo(width - right - 10));
            expect(target.top, greaterThanOrEqualTo(0));
            expect(target.bottom, lessThanOrEqualTo(height - 34 - 8));
          }
          expect(direction == TextDirection.ltr ? pill.right <= create.left : create.right <= pill.left, isTrue);

          messenger.currentState!.showSnackBar(
            const SnackBar(content: Text('Wallpaper set'), behavior: SnackBarBehavior.floating),
          );
          await tester.pumpAndSettle();
          final Rect feedback = tester.getRect(
            find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first,
          );
          // The band starts 8 above the top control, and feedback keeps 8 more above the band.
          expect(feedback.bottom, closeTo(top - 8 - 8, 0.01));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _semanticsTest('guest on at 390: the bottom avatar shows and pushes the profile route', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..profilePhoto = '';
    final _TestRouter router = await _pump(tester, width: 390, bloc: _bloc(0), prefs: _prefs(tester, oneHanded: true));

    expect(find.bySemanticsLabel('Your profile'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Your profile'));
    await tester.pumpAndSettle();

    expect(router.stack.last.name, ProfileRoute.name);
  });

  testWidgets('one-handed RTL Duo keeps all controls in the physical right safe column', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    const contentKey = Key('duo-content');
    await _pump(
      tester,
      width: 466,
      rightInset: 84,
      bloc: _bloc(2),
      prefs: _prefs(tester, oneHanded: true),
      direction: TextDirection.rtl,
      textScale: 2,
      content: const SizedBox.expand(key: contentKey),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(contentKey)).right, 382);
    expect(tester.widget<PrismBottomNav>(find.byType(PrismBottomNav)).axis, Axis.vertical);
    for (final control in [
      find.bySemanticsLabel('Your profile'),
      find.byTooltip('Notifications'),
      find.byType(PrismBottomNav),
      find.byType(PrismFab),
    ]) {
      final Rect target = tester.getRect(control);
      expect(target.left, greaterThanOrEqualTo(382));
      expect(target.right, lessThanOrEqualTo(466));
      expect(control.hitTestable(), findsOneWidget);
    }
    expect(tester.getSize(find.bySemanticsLabel('Your profile')), const Size(44, 44));
    expect(tester.getSize(find.byTooltip('Notifications')), const Size(44, 44));
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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
