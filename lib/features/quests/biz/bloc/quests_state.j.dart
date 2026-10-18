part of 'quests_bloc.j.dart';

@freezed
abstract class QuestsState with _$QuestsState {
  const factory QuestsState({QuestState? quests, @Default(<QuestAward>[]) List<QuestAward> awards}) = _QuestsState;
}
