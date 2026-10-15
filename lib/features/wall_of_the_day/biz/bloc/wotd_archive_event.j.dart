part of 'wotd_archive_bloc.j.dart';

@freezed
abstract class WotdArchiveEvent with _$WotdArchiveEvent {
  const factory WotdArchiveEvent.started() = _Started;
  const factory WotdArchiveEvent.refreshRequested() = _RefreshRequested;
}
