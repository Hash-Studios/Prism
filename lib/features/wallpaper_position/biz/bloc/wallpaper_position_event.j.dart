part of 'wallpaper_position_bloc.j.dart';

@freezed
abstract class WallpaperPositionEvent with _$WallpaperPositionEvent {
  /// Loads the wall. [imageUrl] is a web address or a local file path.
  const factory WallpaperPositionEvent.started({required String imageUrl, String? thumbnailUrl, String? entryPoint}) =
      _Started;
  const factory WallpaperPositionEvent.fitChanged(PlacementFit fit) = _FitChanged;
  const factory WallpaperPositionEvent.moved({required double dx, required double dy, required double zoom}) = _Moved;
  const factory WallpaperPositionEvent.dimChanged(double dim) = _DimChanged;
  const factory WallpaperPositionEvent.previewModeChanged(PlacementPreviewMode mode) = _PreviewModeChanged;
  const factory WallpaperPositionEvent.resetRequested() = _ResetRequested;

  /// Renders the wall at [outputSize] pixels for the Set screen.
  const factory WallpaperPositionEvent.doneRequested({required Size outputSize}) = _DoneRequested;
}
