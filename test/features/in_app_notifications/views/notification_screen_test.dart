import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/views/pages/notification_screen.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_visuals.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../in_app_notification_fixture.dart';

class _MockBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState> implements InAppNotificationsBloc {}

void main() {
  late _MockBloc bloc;

  setUp(() async {
    await getIt.reset();
    bloc = _MockBloc();
    getIt.registerSingleton<InAppNotificationsBloc>(bloc);
  });

  tearDown(getIt.reset);

  Future<void> pump(WidgetTester tester, InAppNotificationsState state) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  InAppNotificationsState loaded(List items, {LoadStatus status = LoadStatus.success}) =>
      InAppNotificationsState.initial().copyWith(status: status, items: List.from(items));

  testWidgets('loading shows a skeleton and no actions to clear', (tester) async {
    await pump(tester, InAppNotificationsState.initial().copyWith(status: LoadStatus.loading));

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.byTooltip('Clear inbox'), findsNothing);
    expect(find.byTooltip('Notification preferences'), findsOneWidget);
  });

  testWidgets('an empty inbox says so', (tester) async {
    await pump(tester, loaded(const []));

    expect(find.text('No notifications'), findsOneWidget);
    expect(find.text('New followers, approvals and the Wall of the Day show up here.'), findsOneWidget);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    await pump(tester, InAppNotificationsState.initial().copyWith(status: LoadStatus.failure));

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const InAppNotificationsEvent.refreshRequested())).called(1);
  });

  testWidgets('rows show the title, body, a day header and an unread dot, without the trailing emoji', (tester) async {
    final DateTime now = DateTime.now();
    await pump(
      tester,
      loaded(<Object>[
        notification('a', title: 'Wall approved ✅', body: 'Your wall is live.', createdAt: now),
        notification('b', title: 'Your streak is about to break!', body: 'Open Prism.', createdAt: now, read: true),
      ]),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Wall approved'), findsOneWidget);
    expect(find.text('Wall approved ✅'), findsNothing);
    expect(find.text('Your wall is live.'), findsOneWidget);
    expect(find.byType(UnreadDot), findsOneWidget);
    expect(find.byTooltip('Clear inbox'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('a group expands to its rows', (tester) async {
    final DateTime now = DateTime.now();
    await pump(
      tester,
      loaded(<Object>[
        notification('a', title: 'You have a new follower!', body: 'Sam is now following you.', createdAt: now),
        notification('b', title: 'You have a new follower!', body: 'Kim is now following you.', createdAt: now),
      ]),
    );

    expect(find.text('Sam'), findsNothing);
    await tester.tap(find.text('You have a new follower!'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Kim'), findsOneWidget);
  });

  test('cleanNotificationTitle strips trailing emoji only', () {
    expect(cleanNotificationTitle('New Premium Wall for review! 🎉'), 'New Premium Wall for review!');
    expect(cleanNotificationTitle('Streak 🔥 alert'), 'Streak 🔥 alert');
    expect(cleanNotificationTitle('🎉'), '🎉');
  });
}
