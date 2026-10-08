import 'package:equatable/equatable.dart';

/// How the wall fills the screen frame.
enum PlacementFit {
  /// Covers the screen. The sides or the top and bottom are cropped.
  fill,

  /// Shows the whole wall over a blurred copy of itself.
  fitBlur,

  /// Shows the whole wall over its dominant colour.
  fitColor,
}

/// Which system layer the preview draws over the wall.
enum PlacementPreviewMode { lock, home }

/// Where the wall sits on the screen. The preview and the render both read it.
///
/// [dx] and [dy] run from -1 to 1 and say which part of the wall shows: -1 is the left or top edge, 1 the right or
/// bottom edge, 0 the centre. They do nothing when the wall has no room to move.
class WallpaperPlacement extends Equatable {
  const WallpaperPlacement({
    this.fit = PlacementFit.fill,
    this.dx = 0,
    this.dy = 0,
    this.zoom = minZoom,
    this.dim = 0,
    this.previewMode = PlacementPreviewMode.lock,
  });

  static const double minZoom = 1;
  static const double maxZoom = 4;
  static const double maxDim = 0.6;

  final PlacementFit fit;
  final double dx;
  final double dy;
  final double zoom;

  /// Black overlay strength, from 0 to [maxDim].
  final double dim;
  final PlacementPreviewMode previewMode;

  bool get isZoomed => zoom > minZoom + 0.01;

  /// Dim in steps of 10%, for analytics.
  int get dimBucket => (dim * 10).round();

  WallpaperPlacement copyWith({
    PlacementFit? fit,
    double? dx,
    double? dy,
    double? zoom,
    double? dim,
    PlacementPreviewMode? previewMode,
  }) {
    return WallpaperPlacement(
      fit: fit ?? this.fit,
      dx: (dx ?? this.dx).clamp(-1.0, 1.0),
      dy: (dy ?? this.dy).clamp(-1.0, 1.0),
      zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom),
      dim: (dim ?? this.dim).clamp(0.0, maxDim),
      previewMode: previewMode ?? this.previewMode,
    );
  }

  @override
  List<Object?> get props => <Object?>[fit, dx, dy, zoom, dim, previewMode];
}
