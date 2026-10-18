part of 'quests_bloc.j.dart';

@freezed
abstract class QuestsEvent with _$QuestsEvent {
  const factory QuestsEvent.started() = _Started;
  const factory QuestsEvent.refreshed() = _Refreshed;
  const factory QuestsEvent.awardsShown() = _AwardsShown;
}
