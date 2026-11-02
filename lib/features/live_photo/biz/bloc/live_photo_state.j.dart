part of 'live_photo_bloc.j.dart';

enum LivePhotoPhase { picking, exporting, saved, refused, failed }

@freezed
abstract class LivePhotoState with _$LivePhotoState {
  const factory LivePhotoState({
    required LivePhotoPhase phase,
    required List<MotionStyle> styles,
    required MotionStyle style,
    required bool isPro,

    /// Paid style id to the end of its coin unlock, as the server stored it.
    @Default(<String, DateTime>{}) Map<String, DateTime> unlockedStyles,
    @Default(0) double progress,
    @Default(false) bool cancelling,
    LiveExportOutcome? outcome,
  }) = _LivePhotoState;
}

extension LivePhotoStateLocks on LivePhotoState {
  bool isLocked(MotionStyle style, {DateTime? now}) =>
      isLiveStyleLocked(style.name, isFree: style.isFree, isPro: isPro, unlockedStyles: unlockedStyles, now: now);
}
