import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/draw/biz/bloc/draw_bloc.j.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:Prism/features/draw/domain/repositories/draw_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

class _MockRepository extends Mock implements DrawRepository {}

final DrawEntity _draw = DrawEntity(
  weekKey: '2026-W42',
  status: 'open',
  closesAt: DateTime.utc(2026, 10, 19),
  tickets: 4,
  participants: 3,
  prizeProMonths: 1,
  prizeItemId: 'frame_prism',
);

Map<String, Object?> _bought(int tickets) => <String, Object?>{
  'success': true,
  'changed': true,
  'previousBalance': 100,
  'currentBalance': 80,
  'delta': -20,
  'reason': 'ok',
  'tickets': tickets,
  'weekKey': '2026-W42',
  'closesAt': DateTime.utc(2026, 10, 19).millisecondsSinceEpoch,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  late _MockRepository repository;
  late FakeAppAnalytics analytics;

  setUp(() async {
    await backend.install();
    CoinsService.instance.balanceNotifier.value = 100;
    repository = _MockRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    when(() => repository.fetchCurrent(any())).thenAnswer((_) async => Result.success(_draw));
    when(() => repository.fetchLastSettled()).thenAnswer((_) async => Result.success(null));
    when(() => repository.fetchMyTickets(any(), any())).thenAnswer((_) async => Result.success(2));
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  test('started loads the draw, my tickets and the last winner', () async {
    final DrawEntity settled = _draw.copyWith(status: 'settled', winnerName: 'Ana');
    when(() => repository.fetchLastSettled()).thenAnswer((_) async => Result.success(settled));
    final DrawBloc bloc = DrawBloc(repository)..add(const DrawEvent.started());

    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    expect((bloc.state.draw, bloc.state.myTickets, bloc.state.lastWinner), (_draw, 2, settled));
    verify(() => repository.fetchMyTickets(any(), backend.userId)).called(1);
    await bloc.close();
  });

  test('a failed draw read is a failure state', () async {
    when(() => repository.fetchCurrent(any())).thenAnswer((_) async => Result.error(const ServerFailure('x')));
    final DrawBloc bloc = DrawBloc(repository)..add(const DrawEvent.started());

    await bloc.stream.firstWhere((s) => s.status == LoadStatus.failure);

    expect(bloc.state.draw, isNull);
    await bloc.close();
  });

  test('a bought ticket updates my count, the pot and tracks the event', () async {
    backend.onCall = (_, _) async => _bought(3);
    final DrawBloc bloc = DrawBloc(repository)..add(const DrawEvent.started());
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    bloc.add(const DrawEvent.ticketRequested());
    await bloc.stream.firstWhere((s) => s.purchase != null && !s.busy);

    expect(bloc.state.purchase!.outcome, DrawTicketOutcome.bought);
    expect((bloc.state.myTickets, bloc.state.draw!.tickets, bloc.state.draw!.participants), (3, 5, 3));
    final DrawTicketBoughtEvent event = analytics.events.whereType<DrawTicketBoughtEvent>().single;
    expect((event.weekKey, event.tickets), ('2026-W42', 3));
    await bloc.close();
  });

  test('a first ticket adds a participant', () async {
    when(() => repository.fetchMyTickets(any(), any())).thenAnswer((_) async => Result.success(0));
    backend.onCall = (_, _) async => _bought(1);
    final DrawBloc bloc = DrawBloc(repository)..add(const DrawEvent.started());
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    bloc.add(const DrawEvent.ticketRequested());
    await bloc.stream.firstWhere((s) => s.purchase != null && !s.busy);

    expect((bloc.state.draw!.tickets, bloc.state.draw!.participants), (5, 4));
    await bloc.close();
  });

  test('a refusal keeps the counts and reports the outcome', () async {
    backend.onCall = (_, _) async => <String, Object?>{
      'success': false,
      'changed': false,
      'previousBalance': 100,
      'currentBalance': 100,
      'delta': 0,
      'reason': 'draw_pro_not_eligible',
    };
    final DrawBloc bloc = DrawBloc(repository)..add(const DrawEvent.started());
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    bloc.add(const DrawEvent.ticketRequested());
    await bloc.stream.firstWhere((s) => s.purchase != null && !s.busy);

    expect(bloc.state.purchase!.outcome, DrawTicketOutcome.proNotEligible);
    expect((bloc.state.myTickets, bloc.state.draw!.tickets), (2, 4));
    expect(analytics.events.whereType<DrawTicketBoughtEvent>(), isEmpty);
    await bloc.close();
  });
}
