part of 'quests_bloc.j.dart';

@freezed
abstract class QuestsState with _$QuestsState {
  const factory QuestsState({
    QuestState? quests,
    @Default(<QuestAward>[]) List<QuestAward> awards,
    @Default(false) bool opening,

    /// The last chest result. The view shows the chest sheet when it changes.
    ChestResult? chest,
  }) = _QuestsState;
}
