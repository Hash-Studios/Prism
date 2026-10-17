part of 'draw_bloc.j.dart';

@freezed
abstract class DrawEvent with _$DrawEvent {
  const factory DrawEvent.started() = _Started;
  const factory DrawEvent.refreshed() = _Refreshed;
  const factory DrawEvent.ticketRequested() = _TicketRequested;
}
