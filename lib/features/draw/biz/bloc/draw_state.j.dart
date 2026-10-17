part of 'draw_bloc.j.dart';

@freezed
abstract class DrawState with _$DrawState {
  const factory DrawState({
    required LoadStatus status,
    required int myTickets,
    required bool busy,
    DrawEntity? draw,
    DrawEntity? lastWinner,

    /// Set by each ticket purchase so the page can show one toast per outcome.
    DrawTicketResult? purchase,
  }) = _DrawState;

  factory DrawState.initial() => const DrawState(status: LoadStatus.initial, myTickets: 0, busy: false);
}
