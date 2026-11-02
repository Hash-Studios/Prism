import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

sealed class WallpaperDetailState extends Equatable {
  const WallpaperDetailState();

  @override
  List<Object?> get props => [];
}

enum WallpaperDetailLoadFailure { notFound, unavailable }

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
    this.tipperCount = 0,
    this.viewsLoading = false,
    this.paletteLoading = true,
    this.colors,
    this.accent,
    this.colorChanged = false,
    this.panelClosed = true,
    this.panelCollapsed = true,
    this.panelScrollInProgress = false,
    this.recommendations = const RecommendationState.initial(),
    this.variants,
  });

  final FeedItemEntity entity;
  final String? views;

  /// Times the wall was set, from `wallpaper_stats`. Null until known.
  final int? setCount;

  /// People who tipped the wall, from `wallpaper_stats`. 0 until known.
  final int tipperCount;
  final bool viewsLoading;
  final bool paletteLoading;
  final List<Color>? colors;
  final Color? accent;
  final bool colorChanged;
  final bool panelClosed;
  final bool panelCollapsed;
  final bool panelScrollInProgress;
  final RecommendationState recommendations;

  /// The colour variants of the wall, or null when it has none. [entity] is the one on screen.
  final VariantGroup? variants;

  /// Position of [entity] in [variants], or -1.
  int get variantIndex => switch (entity) {
    PrismFeedItem(:final wallpaper) => variants?.indexOfDoc(wallpaper.firestoreDocumentId) ?? -1,
    _ => -1,
  };

  /// The colour variation applied to the wallpaper, or null while the original shows.
  Color? get tint => colorChanged ? accent : null;

  WallpaperDetailLoaded copyWith({
    FeedItemEntity? entity,
    String? views,
    int? setCount,
    int? tipperCount,
    bool? viewsLoading,
    bool? paletteLoading,
    List<Color>? colors,
    Color? accent,
    bool? colorChanged,
    bool? panelClosed,
    bool? panelCollapsed,
    bool? panelScrollInProgress,
    RecommendationState? recommendations,
    VariantGroup? variants,
  }) {
    return WallpaperDetailLoaded(
      entity: entity ?? this.entity,
      views: views ?? this.views,
      setCount: setCount ?? this.setCount,
      tipperCount: tipperCount ?? this.tipperCount,
      viewsLoading: viewsLoading ?? this.viewsLoading,
      paletteLoading: paletteLoading ?? this.paletteLoading,
      colors: colors ?? this.colors,
      accent: accent ?? this.accent,
      colorChanged: colorChanged ?? this.colorChanged,
      panelClosed: panelClosed ?? this.panelClosed,
      panelCollapsed: panelCollapsed ?? this.panelCollapsed,
      panelScrollInProgress: panelScrollInProgress ?? this.panelScrollInProgress,
      recommendations: recommendations ?? this.recommendations,
      variants: variants ?? this.variants,
    );
  }

  @override
  List<Object?> get props => [
    entity,
    views,
    setCount,
    tipperCount,
    viewsLoading,
    paletteLoading,
    colors,
    accent,
    colorChanged,
    panelClosed,
    panelCollapsed,
    panelScrollInProgress,
    recommendations,
    variants,
  ];
}

final class WallpaperDetailError extends WallpaperDetailState {
  const WallpaperDetailError({required this.failure, this.thumbnailUrl});

  final WallpaperDetailLoadFailure failure;

  /// The thumbnail the link or tile carried, shown behind the message.
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [failure, thumbnailUrl];
}
