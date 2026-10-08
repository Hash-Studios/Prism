import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
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
    this.setCount,
    this.viewsLoading = false,
    this.paletteLoading = true,
    this.colors,
    this.accent,
    this.colorChanged = false,
    this.panelClosed = true,
    this.panelCollapsed = true,
    this.panelScrollInProgress = false,
  });

  final FeedItemEntity entity;
  final String? views;

  /// Times the wall was set, from `wallpaper_stats`. Null until known.
  final int? setCount;
  final bool viewsLoading;
  final bool paletteLoading;
  final List<Color>? colors;
  final Color? accent;
  final bool colorChanged;
  final bool panelClosed;
  final bool panelCollapsed;
  final bool panelScrollInProgress;

  WallpaperDetailLoaded copyWith({
    FeedItemEntity? entity,
    String? views,
    int? setCount,
    bool? viewsLoading,
    bool? paletteLoading,
    List<Color>? colors,
    Color? accent,
    bool? colorChanged,
    bool? panelClosed,
    bool? panelCollapsed,
    bool? panelScrollInProgress,
  }) {
    return WallpaperDetailLoaded(
      entity: entity ?? this.entity,
      views: views ?? this.views,
      setCount: setCount ?? this.setCount,
      viewsLoading: viewsLoading ?? this.viewsLoading,
      paletteLoading: paletteLoading ?? this.paletteLoading,
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
    setCount,
    viewsLoading,
    paletteLoading,
    colors,
    accent,
    colorChanged,
    panelClosed,
    panelCollapsed,
    panelScrollInProgress,
  ];
}

final class WallpaperDetailError extends WallpaperDetailState {
  const WallpaperDetailError({required this.message, this.thumbnailUrl});

  final String message;

  /// The thumbnail the link or tile carried, shown behind the message.
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [message, thumbnailUrl];
}
