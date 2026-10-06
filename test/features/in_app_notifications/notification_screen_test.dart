import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/usecases/notifications_usecases.dart';
import 'package:Prism/features/in_app_notifications/views/pages/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import 'in_app_notification_fixture.dart';

class _MockFetch extends Mock implements FetchNotificationsUseCase {}

class _MockMark extends Mock implements MarkNotificationAsReadUseCase {}

class _MockDelete extends Mock implements DeleteNotificationUseCase {}

class _MockDeleteMany extends Mock implements DeleteNotificationsByIdsUseCase {}

class _MockClear extends Mock implements ClearNotificationsUseCase {}

class _MockMarkAll extends Mock implements MarkAllNotificationsAsReadUseCase {}

class _MockRestore extends Mock implements RestoreNotificationsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchNotificationsParams(syncRemote: true));
    registerFallbackValue(const DeleteNotificationParams(id: 'x'));
    registerFallbackValue(const RestoreNotificationsParams(items: <InAppNotificationEntity>[]));
  });

  late _MockFetch fetch;
  late _MockDelete delete;
  late _MockMarkAll markAll;
  late _MockRestore restore;

  final unread = notification('u1', title: 'Unread title');
  final read = notification('r1', title: 'Read title', read: true, createdAt: DateTime.utc(2023));

  Future<void> pumpScreen(WidgetTester tester) async {
    when(() => fetch(any())).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[unread, read]));
    getIt.registerSingleton<InAppNotificationsBloc>(
      InAppNotificationsBloc(fetch, _MockMark(), delete, _MockDeleteMany(), _MockClear(), markAll, restore),
    );
    await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    PrismHaptics.enabled = false;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    await getIt.reset();
    fetch = _MockFetch();
    delete = _MockDelete();
    markAll = _MockMarkAll();
    restore = _MockRestore();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('unread rows get a bold title and a dot, read rows do not', (tester) async {
    await pumpScreen(tester);

    final FontWeight? unreadWeight = tester.widget<Text>(find.text('Unread title')).style?.fontWeight;
    final FontWeight? readWeight = tester.widget<Text>(find.text('Read title')).style?.fontWeight;
    expect(unreadWeight, FontWeight.w700);
    expect(readWeight, FontWeight.w500);
    expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_UnreadDot'), findsOneWidget);
  });

  testWidgets('Mark all as read calls the use case', (tester) async {
    when(
      () => markAll(const NoParams()),
    ).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[unread.copyWith(read: true), read]));
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();

    verify(() => markAll(const NoParams())).called(1);
    expect(find.byTooltip('Mark all as read'), findsNothing);
  });

  testWidgets('swiping deletes without a dialog and Undo restores the notification', (tester) async {
    when(() => delete(any())).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[read]));
    when(() => restore(any())).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[unread, read]));
    await pumpScreen(tester);

    await tester.drag(find.text('Unread title'), const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verify(() => delete(any(that: isA<DeleteNotificationParams>().having((p) => p.id, 'id', 'u1')))).called(1);
    expect(find.text('Notification removed'), findsOneWidget);
    expect(find.text('Unread title'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    verify(
      () => restore(any(that: isA<RestoreNotificationsParams>().having((p) => p.items.single.id, 'id', 'u1'))),
    ).called(1);
    expect(find.text('Unread title'), findsOneWidget);
  });
}
