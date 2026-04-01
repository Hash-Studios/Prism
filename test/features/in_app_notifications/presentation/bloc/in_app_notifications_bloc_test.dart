import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/usecases/notifications_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchNotificationsUseCase extends Mock implements FetchNotificationsUseCase {}

class _MockMarkNotificationAsReadUseCase extends Mock implements MarkNotificationAsReadUseCase {}

class _MockDeleteNotificationUseCase extends Mock implements DeleteNotificationUseCase {}

class _MockDeleteNotificationsByIdsUseCase extends Mock implements DeleteNotificationsByIdsUseCase {}

class _MockClearNotificationsUseCase extends Mock implements ClearNotificationsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchNotificationsParams(syncRemote: true));
    registerFallbackValue(const MarkNotificationAsReadParams(id: 'notif-1'));
    registerFallbackValue(const DeleteNotificationParams(id: 'notif-1'));
    registerFallbackValue(const DeleteNotificationsByIdsParams(ids: <String>['a']));
  });

  late _MockFetchNotificationsUseCase fetchUseCase;
  late _MockMarkNotificationAsReadUseCase markUseCase;
  late _MockDeleteNotificationUseCase deleteUseCase;
  late _MockDeleteNotificationsByIdsUseCase deleteManyUseCase;
  late _MockClearNotificationsUseCase clearUseCase;

  final unread = InAppNotificationEntity(
    id: 'notif-1',
    title: 't',
    pageName: '/route',
    body: 'b',
    imageUrl: 'img',
    arguments: <Object>[],
    url: '',
    createdAt: DateTime(2024),
    read: false,
  );

  final read = InAppNotificationEntity(
    id: 'notif-1',
    title: 't',
    pageName: '/route',
    body: 'b',
    imageUrl: 'img',
    arguments: <Object>[],
    url: '',
    createdAt: DateTime(2024),
    read: true,
  );

  setUp(() {
    fetchUseCase = _MockFetchNotificationsUseCase();
    markUseCase = _MockMarkNotificationAsReadUseCase();
    deleteUseCase = _MockDeleteNotificationUseCase();
    deleteManyUseCase = _MockDeleteNotificationsByIdsUseCase();
    clearUseCase = _MockClearNotificationsUseCase();

    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[unread]));

    when(() => markUseCase(any())).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[read]));

    when(() => deleteUseCase(any())).thenAnswer((_) async => Result.success(const <InAppNotificationEntity>[]));

    when(() => deleteManyUseCase(any())).thenAnswer((_) async => Result.success(const <InAppNotificationEntity>[]));

    when(
      () => clearUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(const <InAppNotificationEntity>[]));
  });

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'loads notifications and marks one as read',
    build: () => InAppNotificationsBloc(
      fetchUseCase,
      markUseCase,
      deleteUseCase,
      deleteManyUseCase,
      clearUseCase,
    ),
    act: (bloc) => bloc
      ..add(const InAppNotificationsEvent.started(syncRemote: true))
      ..add(const InAppNotificationsEvent.markReadRequested(id: 'notif-1')),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.unreadCount, 0);
      expect(bloc.state.items.first.read, isTrue);
    },
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'localReloadRequested refreshes from cache without forcing loading state on success path',
    build: () => InAppNotificationsBloc(
      fetchUseCase,
      markUseCase,
      deleteUseCase,
      deleteManyUseCase,
      clearUseCase,
    ),
    seed: () => InAppNotificationsState(
      status: LoadStatus.success,
      actionStatus: ActionStatus.success,
      items: const <InAppNotificationEntity>[],
      unreadCount: 0,
    ),
    act: (bloc) => bloc.add(const InAppNotificationsEvent.localReloadRequested()),
    verify: (bloc) {
      verify(() => fetchUseCase(const FetchNotificationsParams(syncRemote: false))).called(1);
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items, isNotEmpty);
    },
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'deleteManyRequested removes several ids in one pass',
    build: () => InAppNotificationsBloc(
      fetchUseCase,
      markUseCase,
      deleteUseCase,
      deleteManyUseCase,
      clearUseCase,
    ),
    seed: () => const InAppNotificationsState(
      status: LoadStatus.success,
      actionStatus: ActionStatus.success,
      items: <InAppNotificationEntity>[],
      unreadCount: 0,
    ),
    act: (bloc) => bloc.add(const InAppNotificationsEvent.deleteManyRequested(ids: <String>['a', 'b'])),
    verify: (_) {
      verify(() => deleteManyUseCase(any(that: isA<DeleteNotificationsByIdsParams>()))).called(1);
    },
  );
}
