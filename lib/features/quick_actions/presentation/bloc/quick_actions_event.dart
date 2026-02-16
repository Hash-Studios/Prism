part of 'quick_actions_bloc.dart';

@freezed
abstract class QuickActionsEvent with _$QuickActionsEvent {
  const factory QuickActionsEvent.started({
    @Default(true) bool setupShortcuts,
  }) = _Started;
  const factory QuickActionsEvent.shortcutsSetupRequested() =
      _ShortcutsSetupRequested;
  const factory QuickActionsEvent.actionReceived(QuickActionEntity action) =
      _ActionReceived;
  const factory QuickActionsEvent.historyCleared() = _HistoryCleared;
}
