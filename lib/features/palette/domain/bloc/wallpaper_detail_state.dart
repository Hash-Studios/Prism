import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

sealed class WallpaperDetailState extends Equatable {
  const WallpaperDetailState();

  @override
  List<Object?> get props => [];
}

final class WallpaperDetailInitial extends WallpaperDetailState {
  const WallpaperDetailInitial();
}

final class WallpaperDetailLoading extends WallpaperDetailState {
  const WallpaperDetailLoading({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  List<Object?> get props => [thumbnailUrl];
}

final class WallpaperDetailLoaded extends WallpaperDetailState {
  const WallpaperDetailLoaded({
    required this.entity,
    this.views,
    this.viewsLoading = false,
    this.colors,
    this.accent,
    this.colorChanged = false,
    this.panelClosed = true,
    this.panelCollapsed = true,
    this.panelScrollInProgress = false,
  });

  final WallpaperDetailEntity entity;
  final String? views;
  final bool viewsLoading;
  final List<Color?>? colors;
  final Color? accent;
  final bool colorChanged;
  final bool panelClosed;
  final bool panelCollapsed;
  final bool panelScrollInProgress;

  WallpaperDetailLoaded copyWith({
    WallpaperDetailEntity? entity,
    String? views,
    bool? viewsLoading,
    List<Color?>? colors,
    Color? accent,
    bool? colorChanged,
    bool? panelClosed,
    bool? panelCollapsed,
    bool? panelScrollInProgress,
  }) {
    return WallpaperDetailLoaded(
      entity: entity ?? this.entity,
      views: views ?? this.views,
      viewsLoading: viewsLoading ?? this.viewsLoading,
      colors: colors ?? this.colors,
      accent: accent ?? this.accent,
      colorChanged: colorChanged ?? this.colorChanged,
      panelClosed: panelClosed ?? this.panelClosed,
      panelCollapsed: panelCollapsed ?? this.panelCollapsed,
      panelScrollInProgress: panelScrollInProgress ?? this.panelScrollInProgress,
    );
  }

  @override
  List<Object?> get props => [
    entity,
    views,
    viewsLoading,
    colors,
    accent,
    colorChanged,
    panelClosed,
    panelCollapsed,
    panelScrollInProgress,
  ];
}

final class WallpaperDetailError extends WallpaperDetailState {
  const WallpaperDetailError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
