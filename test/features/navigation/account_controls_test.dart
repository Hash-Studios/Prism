import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/account_controls.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

void main() {
  testWidgets('the top bell keeps its unread dot on the physical right in RTL', (tester) async {
    final _MockNotificationsBloc bloc = _MockNotificationsBloc();
    final StreamController<InAppNotificationsState> states = StreamController<InAppNotificationsState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: InAppNotificationsState.initial());
    await tester.pumpWidget(
      BlocProvider<InAppNotificationsBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android, materialTapTargetSize: MaterialTapTargetSize.padded),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: NotificationBell(source: NotificationsEntrySourceValue.top)),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byTooltip('Notifications')).width, greaterThanOrEqualTo(44));
    expect(find.descendant(of: find.byType(NotificationBell), matching: find.byType(Positioned)), findsNothing);

    states.add(InAppNotificationsState.initial().copyWith(unreadCount: 1));
    await tester.pump();
    expect(find.descendant(of: find.byType(NotificationBell), matching: find.byType(Positioned)), findsOneWidget);
    final Finder dot = find.descendant(
      of: find.descendant(of: find.byType(NotificationBell), matching: find.byType(Positioned)),
      matching: find.byType(Container),
    );
    expect(tester.getCenter(dot).dx, greaterThan(tester.getCenter(find.byIcon(Icons.notifications_none_rounded)).dx));

    states.add(InAppNotificationsState.initial().copyWith(unreadCount: 0));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(NotificationBell), matching: find.byType(Positioned)), findsNothing);
  });

  testWidgets('the floating bell places its unread dot at the directional end in RTL', (tester) async {
    final _MockNotificationsBloc bloc = _MockNotificationsBloc();
    final StreamController<InAppNotificationsState> states = StreamController<InAppNotificationsState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: InAppNotificationsState.initial());
    await tester.pumpWidget(
      BlocProvider<InAppNotificationsBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android, materialTapTargetSize: MaterialTapTargetSize.padded),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: NotificationBell(source: NotificationsEntrySourceValue.bottom)),
          ),
        ),
      ),
    );

    expect(
      find.descendant(of: find.byType(NotificationBell), matching: find.byType(PositionedDirectional)),
      findsNothing,
    );
    expect(tester.getSize(find.byTooltip('Notifications')), const Size(44, 44));
    states.add(InAppNotificationsState.initial().copyWith(unreadCount: 1));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(NotificationBell), matching: find.byType(PositionedDirectional)),
      findsOneWidget,
    );
    final Finder dot = find.descendant(
      of: find.descendant(of: find.byType(NotificationBell), matching: find.byType(PositionedDirectional)),
      matching: find.byType(Container),
    );
    expect(tester.getCenter(dot).dx, lessThan(tester.getCenter(find.byIcon(Icons.notifications_none_rounded)).dx));

    states.add(InAppNotificationsState.initial().copyWith(unreadCount: 0));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(NotificationBell), matching: find.byType(PositionedDirectional)),
      findsNothing,
    );
  });

  testWidgets('the narrow account button keeps its 44 pixel target and clears its unread dot live', (tester) async {
    final _MockNotificationsBloc bloc = _MockNotificationsBloc();
    final StreamController<InAppNotificationsState> states = StreamController<InAppNotificationsState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: InAppNotificationsState.initial().copyWith(unreadCount: 1));
    await tester.pumpWidget(
      BlocProvider<InAppNotificationsBloc>.value(
        value: bloc,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: AccountButton())),
        ),
      ),
    );

    expect(tester.getSize(find.byType(AccountButton)), const Size(44, 44));
    expect(
      find.descendant(of: find.byType(AccountButton), matching: find.byType(PositionedDirectional)),
      findsOneWidget,
    );

    states.add(InAppNotificationsState.initial().copyWith(unreadCount: 0));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AccountButton), matching: find.byType(PositionedDirectional)), findsNothing);
  });

  testWidgets('the account sheet reads the bloc and updates its unread count live', (tester) async {
    final _MockNotificationsBloc bloc = _MockNotificationsBloc();
    final StreamController<InAppNotificationsState> states = StreamController<InAppNotificationsState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: InAppNotificationsState.initial().copyWith(unreadCount: 1));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<InAppNotificationsBloc>.value(
          value: bloc,
          child: const Scaffold(body: Center(child: AccountButton())),
        ),
      ),
    );

    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(find.text(l10n.navUnreadCount(1)), findsOneWidget);

    states.add(InAppNotificationsState.initial().copyWith(unreadCount: 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.navUnreadCount(1)), findsNothing);
    expect(find.text(l10n.notifTitle), findsOneWidget);
  });
}
