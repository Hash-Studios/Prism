part of 'wotd_bloc.j.dart';

@freezed
abstract class WotdEvent with _$WotdEvent {
  const factory WotdEvent.started() = _Started;
}
