import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:Prism/features/draw/domain/repositories/draw_repository.dart';
import 'package:Prism/features/leaderboard/domain/week_key.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'draw_event.j.dart';
part 'draw_state.j.dart';
part 'draw_bloc.j.freezed.dart';

@injectable
class DrawBloc extends Bloc<DrawEvent, DrawState> {
  DrawBloc(this._repository) : super(DrawState.initial()) {
    on<_Started>((_, emit) => _load(emit));
    on<_Refreshed>((_, emit) => _load(emit));
    on<_TicketRequested>(_onTicketRequested);
  }

  final DrawRepository _repository;

  Future<void> _load(Emitter<DrawState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    final String weekKey = isoWeekKey(DateTime.now().toUtc());
    final results = await (
      _repository.fetchCurrent(weekKey),
      _repository.fetchLastSettled(),
      _repository.fetchMyTickets(weekKey, app_state.prismUser.id),
    ).wait;
    final draw = results.$1.data;
    if (draw == null) {
      emit(state.copyWith(status: LoadStatus.failure));
      return;
    }
    emit(
      state.copyWith(
        status: LoadStatus.success,
        draw: draw,
        lastWinner: results.$2.data,
        myTickets: results.$3.data ?? state.myTickets,
      ),
    );
  }

  Future<void> _onTicketRequested(_TicketRequested event, Emitter<DrawState> emit) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, purchase: null));
    final DrawTicketResult result = await CoinsService.instance.buyDrawTicket();
    if (result.outcome == DrawTicketOutcome.bought) {
      unawaited(analytics.track(DrawTicketBoughtEvent(weekKey: result.weekKey, tickets: result.tickets)));
      final DrawEntity? draw = state.draw;
      emit(
        state.copyWith(
          busy: false,
          purchase: result,
          myTickets: result.tickets,
          draw: draw?.copyWith(
            tickets: draw.tickets + 1,
            participants: state.myTickets == 0 ? draw.participants + 1 : draw.participants,
          ),
        ),
      );
    } else {
      emit(state.copyWith(busy: false, purchase: result));
    }
  }
}
