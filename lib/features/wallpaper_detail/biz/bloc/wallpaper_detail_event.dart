import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/wallpaper_detail_entity.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

sealed class WallpaperDetailEvent extends Equatable {
  const WallpaperDetailEvent();

  @override
  List<Object?> get props => [];
}

final class LoadFromEntity extends WallpaperDetailEvent {
  const LoadFromEntity({required this.entity});

  final WallpaperDetailEntity entity;

  @override
  List<Object?> get props => [entity];
}

final class LoadFromId extends WallpaperDetailEvent {
  const LoadFromId({required this.wallId, required this.source, this.thumbnailUrl});

  final String wallId;
  final WallpaperSource source;
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [wallId, source, thumbnailUrl];
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
