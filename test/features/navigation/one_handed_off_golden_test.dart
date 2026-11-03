import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
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

/// The goldens were drawn from master before one-handed controls existed. With the option off, the top bar and the
/// bottom row must still match them pixel for pixel.
void main() {
  late PrismUsersV2 previousUser;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    previousUser = app_state.prismUser;
    app_state.prismUser = profileUser(profilePhoto: '', username: 'mira');
  });
  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = previousUser;
  });

  Future<void> pumpOff(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = _MockNotificationsBloc();
    when(() => bloc.state).thenReturn(InAppNotificationsState.initial().copyWith(unreadCount: 2));
    final prefs = ValueNotifier<LayoutPrefs>(const LayoutPrefs());
    addTearDown(prefs.dispose);
    await tester.pumpWidget(
      LayoutPrefsScope(
        prefs: prefs,
        child: BlocProvider<InAppNotificationsBloc>.value(
          value: bloc,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: prismLightThemes.first.theme,
            builder: (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
            home: TabsRouterScope(
              controller: _FakeTabsRouter(),
              stateHash: 0,
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('off, the top bar matches master', (tester) async {
    await pumpOff(tester, const Align(alignment: Alignment.topCenter, child: PrismTopAppBar()));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/top_bar_one_handed_off.png'));
  });

  testWidgets('off, the bottom row matches master', (tester) async {
    await pumpOff(tester, const BottomBar(child: SizedBox.expand()));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/bottom_bar_one_handed_off.png'));
  });
}
