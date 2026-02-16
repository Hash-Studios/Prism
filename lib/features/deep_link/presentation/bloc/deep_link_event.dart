part of 'deep_link_bloc.dart';

@freezed
abstract class DeepLinkEvent with _$DeepLinkEvent {
  const factory DeepLinkEvent.started() = _Started;
  const factory DeepLinkEvent.actionReceived(DeepLinkActionEntity action) =
      _ActionReceived;
  const factory DeepLinkEvent.historyCleared() = _HistoryCleared;
}
