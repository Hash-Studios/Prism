import 'dart:typed_data';
import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

sealed class WallpaperDetailEvent extends Equatable {
  const WallpaperDetailEvent();

  @override
  List<Object?> get props => [];
}

final class LoadFromEntity extends WallpaperDetailEvent {
  const LoadFromEntity({required this.entity, this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen});

  final WallpaperDetailEntity entity;
  final AnalyticsSurfaceValue analyticsSurface;

  @override
  List<Object?> get props => [entity, analyticsSurface];
}

final class LoadFromId extends WallpaperDetailEvent {
  const LoadFromId({
    required this.wallId,
    required this.source,
    this.wallpaperUrl,
    this.thumbnailUrl,
    this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen,
  });

  final String wallId;
  final WallpaperSource source;
  final String? wallpaperUrl;
  final String? thumbnailUrl;
  final AnalyticsSurfaceValue analyticsSurface;

  @override
  List<Object?> get props => [wallId, source, wallpaperUrl, thumbnailUrl, analyticsSurface];
}

final class FetchViews extends WallpaperDetailEvent {
  const FetchViews();
}

final class SelectAccentColor extends WallpaperDetailEvent {
  const SelectAccentColor({required this.color});

  final Color color;

  @override
  List<Object?> get props => [color];
}

final class CycleAccentColor extends WallpaperDetailEvent {
  const CycleAccentColor();
}

final class ResetAccentColor extends WallpaperDetailEvent {
  const ResetAccentColor();
}

final class CaptureScreenshot extends WallpaperDetailEvent {
  const CaptureScreenshot({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  List<Object?> get props => [imageBytes];
}

final class OnPanelOpened extends WallpaperDetailEvent {
  const OnPanelOpened();
}

final class OnPanelClosed extends WallpaperDetailEvent {
  const OnPanelClosed();
}

final class OnPanelScrollStart extends WallpaperDetailEvent {
  const OnPanelScrollStart();
}

final class OnPanelScrollEnd extends WallpaperDetailEvent {
  const OnPanelScrollEnd();
}

final class UpdateColorsFromPalette extends WallpaperDetailEvent {
  const UpdateColorsFromPalette({required this.colors});

  final List<Color?> colors;

  @override
  List<Object?> get props => [colors];
}
