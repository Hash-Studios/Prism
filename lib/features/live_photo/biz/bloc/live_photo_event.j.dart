part of 'live_photo_bloc.j.dart';

@freezed
abstract class LivePhotoEvent with _$LivePhotoEvent {
  const factory LivePhotoEvent.styleSelected(MotionStyle style) = _StyleSelected;
  const factory LivePhotoEvent.accessChanged({required bool isPro, required Map<String, DateTime> unlockedStyles}) =
      _AccessChanged;
  const factory LivePhotoEvent.exportRequested({required Size sizePx, required Color tint}) = _ExportRequested;
  const factory LivePhotoEvent.progressed(double fraction) = _Progressed;
  const factory LivePhotoEvent.cancelRequested() = _CancelRequested;

  /// Back to the style picker after a refusal or a failure.
  const factory LivePhotoEvent.reset() = _Reset;
}
