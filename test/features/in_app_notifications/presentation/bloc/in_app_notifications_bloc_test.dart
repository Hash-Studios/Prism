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

class _MockClearNotificationsUseCase extends Mock implements ClearNotificationsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchNotificationsParams(syncRemote: true));
    registerFallbackValue(const MarkNotificationAsReadParams(index: 0));
    registerFallbackValue(const DeleteNotificationParams(index: 0));
  });

  late _MockFetchNotificationsUseCase fetchUseCase;
  late _MockMarkNotificationAsReadUseCase markUseCase;
  late _MockDeleteNotificationUseCase deleteUseCase;
  late _MockClearNotificationsUseCase clearUseCase;

  final unread = InAppNotificationEntity(
    title: 't',
    pageName: '/route',
    body: 'b',
    imageUrl: 'img',
    arguments: <dynamic>[],
    url: '',
    createdAt: DateTime(2024),
    read: false,
  );

  final read = InAppNotificationEntity(
    title: 't',
    pageName: '/route',
    body: 'b',
    imageUrl: 'img',
    arguments: <dynamic>[],
    url: '',
    createdAt: DateTime(2024),
    read: true,
  );

  setUp(() {
    fetchUseCase = _MockFetchNotificationsUseCase();
    markUseCase = _MockMarkNotificationAsReadUseCase();
    deleteUseCase = _MockDeleteNotificationUseCase();
    clearUseCase = _MockClearNotificationsUseCase();

    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[unread]));

    when(() => markUseCase(any())).thenAnswer((_) async => Result.success(<InAppNotificationEntity>[read]));

    when(() => deleteUseCase(any())).thenAnswer((_) async => Result.success(const <InAppNotificationEntity>[]));

    when(
      () => clearUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(const <InAppNotificationEntity>[]));
  });

  blocTest<InAppNotificationsBloc, InAppNotificationsState>(
    'loads notifications and marks one as read',
    build: () => InAppNotificationsBloc(fetchUseCase, markUseCase, deleteUseCase, clearUseCase),
    act: (bloc) => bloc
      ..add(const InAppNotificationsEvent.started(syncRemote: true))
      ..add(const InAppNotificationsEvent.markReadRequested(index: 0)),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.unreadCount, 0);
      expect(bloc.state.items.first.read, isTrue);
    },
  );
}
