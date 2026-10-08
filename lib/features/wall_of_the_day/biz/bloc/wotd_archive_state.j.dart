part of 'wotd_archive_bloc.j.dart';

@freezed
abstract class WotdArchiveState with _$WotdArchiveState {
  const factory WotdArchiveState({required LoadStatus status, required List<WotdPastPick> picks, Failure? failure}) =
      _WotdArchiveState;

  factory WotdArchiveState.initial() => const WotdArchiveState(status: LoadStatus.initial, picks: <WotdPastPick>[]);
}
