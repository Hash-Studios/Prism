import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/usecases/notifications_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../in_app_notification_fixture.dart';

class _MockFetchNotificationsUseCase extends Mock implements FetchNotificationsUseCase {}

class _MockMarkNotificationAsReadUseCase extends Mock implements MarkNotificationAsReadUseCase {}

class _MockDeleteNotificationUseCase extends Mock implements DeleteNotificationUseCase {}

class _MockDeleteNotificationsByIdsUseCase extends Mock implements DeleteNotificationsByIdsUseCase {}

class _MockClearNotificationsUseCase extends Mock implements ClearNotificationsUseCase {}

class _MockMarkAllNotificationsAsReadUseCase extends Mock implements MarkAllNotificationsAsReadUseCase {}

class _MockRestoreNotificationsUseCase extends Mock implements RestoreNotificationsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchNotificationsParams(syncRemote: true));
    registerFallbackValue(const MarkNotificationAsReadParams(id: 'notif-1'));
    registerFallbackValue(const DeleteNotificationParams(id: 'notif-1'));
    registerFallbackValue(const DeleteNotificationsByIdsParams(ids: <String>['a']));
    registerFallbackValue(const RestoreNotificationsParams(items: <InAppNotificationEntity>[]));
  });

  late _MockFetchNotificationsUseCase fetchUseCase;
  late _MockMarkNotificationAsReadUseCase markUseCase;
  late _MockDeleteNotificationUseCase deleteUseCase;
  late _MockDeleteNotificationsByIdsUseCase deleteManyUseCase;
  late _MockClearNotificationsUseCase clearUseCase;
  late _MockMarkAllNotificationsAsReadUseCase markAllUseCase;
  late _MockRestoreNotificationsUseCase restoreUseCase;

  final unread = notification('notif-1');
  final second = notification('notif-2', read: true);
  final markedRead = unread.copyWith(read: true);
  const failure = CacheFailure('disk full');
  final seeded = InAppNotificationsState.initial().copyWith(
    status: LoadStatus.success,
    actionStatus: ActionStatus.success,
    items: <InAppNotificationEntity>[unread, second],
    unreadCount: 1,
  );

  InAppNotificationsState loaded(List<InAppNotificationEntity> items) =>
      seeded.copyWith(items: items, unreadCount: items.where((item) => !item.read).length);

  InAppNotificationsBloc buildBloc() => InAppNotificationsBloc(
    fetchUseCase,
    markUseCase,
    deleteUseCase,
    deleteManyUseCase,
    clearUseCase,
    markAllUseCase,
    restoreUseCase,
  );

  setUp(() {
    fetchUseCase = _MockFetchNotificationsUseCase();
    markUseCase = _MockMarkNotificationAsReadUseCase();
    deleteUseCase = _MockDeleteNotificationUseCase();
    deleteManyUseCase = _MockDeleteNotificationsByIdsUseCase();
    clearUseCase = _MockClearNotificationsUseCase();
    markAllUseCase = _MockMarkAllNotificationsAsReadUseCase();
    restoreUseCase = _MockRestoreNotificationsUseCase();
  });

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'started loads notifications through a loading state and counts the unread ones',
    build: () {
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[unread, second]));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const InAppNotificationsEvent.started(syncRemote: true)),
    expect: () => <InAppNotificationsState>[
      InAppNotificationsState.initial().copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress),
      seeded,
    ],
    verify: (_) => verify(
      () => fetchUseCase(any(that: isA<FetchNotificationsParams>().having((p) => p.syncRemote, 'syncRemote', true))),
    ).called(1),
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'a failed load keeps what was cached and reports the failure',
    build: () {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(failure));
      return buildBloc();
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const InAppNotificationsEvent.refreshRequested()),
    expect: () => <InAppNotificationsState>[
      seeded.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress),
      seeded.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure),
    ],
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'localReloadRequested reads the cache without a loading state',
    build: () {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[unread]));
      return buildBloc();
    },
    seed: () => seeded.copyWith(items: const <InAppNotificationEntity>[], unreadCount: 0),
    act: (bloc) => bloc.add(const InAppNotificationsEvent.localReloadRequested()),
    expect: () => <InAppNotificationsState>[
      loaded(<InAppNotificationEntity>[unread]),
    ],
    verify: (_) => verify(
      () => fetchUseCase(any(that: isA<FetchNotificationsParams>().having((p) => p.syncRemote, 'syncRemote', false))),
    ).called(1),
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'a failed local reload leaves the load status alone',
    build: () {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(failure));
      return buildBloc();
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const InAppNotificationsEvent.localReloadRequested()),
    expect: () => <InAppNotificationsState>[seeded.copyWith(actionStatus: ActionStatus.failure, failure: failure)],
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'markReadRequested publishes the list the use case returns',
    build: () {
      when(
        () => markUseCase(any()),
      ).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[markedRead, second]));
      return buildBloc();
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const InAppNotificationsEvent.markReadRequested(id: 'notif-1')),
    expect: () => <InAppNotificationsState>[
      seeded.copyWith(actionStatus: ActionStatus.inProgress),
      loaded(<InAppNotificationEntity>[markedRead, second]),
    ],
    verify: (_) => verify(
      () => markUseCase(any(that: isA<MarkNotificationAsReadParams>().having((p) => p.id, 'id', 'notif-1'))),
    ).called(1),
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'deleteManyRequested removes several ids in one pass',
    build: () {
      when(() => deleteManyUseCase(any())).thenAnswer((_) async => Result.success(const <InAppNotificationEntity>[]));
      return buildBloc();
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const InAppNotificationsEvent.deleteManyRequested(ids: <String>['notif-1', 'notif-2'])),
    expect: () => <InAppNotificationsState>[
      seeded.copyWith(actionStatus: ActionStatus.inProgress),
      loaded(const <InAppNotificationEntity>[]),
    ],
    verify: (_) => verify(
      () =>
          deleteManyUseCase(any(that: isA<DeleteNotificationsByIdsParams>().having((p) => p.ids, 'ids', hasLength(2)))),
    ).called(1),
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'clearRequested empties the inbox and zeroes the unread count',
    build: () {
      when(
        () => clearUseCase(const NoParams()),
      ).thenAnswer((_) async => Result.success(const <InAppNotificationEntity>[]));
      return buildBloc();
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const InAppNotificationsEvent.clearRequested()),
    expect: () => <InAppNotificationsState>[
      seeded.copyWith(actionStatus: ActionStatus.inProgress),
      loaded(const <InAppNotificationEntity>[]),
    ],
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'deleteRequested keeps the list when the delete fails',
    build: () {
      when(() => deleteUseCase(any())).thenAnswer((_) async => Result.error(failure));
      return buildBloc();
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const InAppNotificationsEvent.deleteRequested(id: 'notif-1')),
    expect: () => <InAppNotificationsState>[
      seeded.copyWith(actionStatus: ActionStatus.inProgress),
      seeded.copyWith(actionStatus: ActionStatus.failure, failure: failure),
    ],
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'markAllReadRequested publishes the list with everything read and a zero unread count',
    build: () {
      when(
        () => markAllUseCase(const NoParams()),
      ).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[markedRead, second]));
      return buildBloc();
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const InAppNotificationsEvent.markAllReadRequested()),
    expect: () => <InAppNotificationsState>[
      seeded.copyWith(actionStatus: ActionStatus.inProgress),
      loaded(<InAppNotificationEntity>[markedRead, second]),
    ],
    verify: (bloc) => expect(bloc.state.unreadCount, 0),
  );

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'restoreRequested puts removed notifications back',
    build: () {
      when(
        () => restoreUseCase(any()),
      ).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[unread, second]));
      return buildBloc();
    },
    seed: () => loaded(<InAppNotificationEntity>[second]),
    act: (bloc) => bloc.add(InAppNotificationsEvent.restoreRequested(items: <InAppNotificationEntity>[unread])),
    expect: () => <InAppNotificationsState>[
      loaded(<InAppNotificationEntity>[second]).copyWith(actionStatus: ActionStatus.inProgress),
      loaded(<InAppNotificationEntity>[unread, second]),
    ],
    verify: (_) => verify(
      () => restoreUseCase(any(that: isA<RestoreNotificationsParams>().having((p) => p.items, 'items', [unread]))),
    ).called(1),
  );
}
