import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';

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
    this.viewsError,
    this.colors,
    this.accent,
    this.colorChanged = false,
    this.screenshotTaken = false,
    this.imageFile,
    this.panelClosed = true,
    this.panelCollapsed = true,
    this.panelScrollInProgress = false,
  });

  final WallpaperDetailEntity entity;
  final String? views;
  final bool viewsLoading;
  final String? viewsError;
  final List<Color?>? colors;
  final Color? accent;
  final bool colorChanged;
  final bool screenshotTaken;
  final File? imageFile;
  final bool panelClosed;
  final bool panelCollapsed;
  final bool panelScrollInProgress;

  WallpaperDetailLoaded copyWith({
    WallpaperDetailEntity? entity,
    String? views,
    bool? viewsLoading,
    String? viewsError,
    List<Color?>? colors,
    Color? accent,
    bool? colorChanged,
    bool? screenshotTaken,
    File? imageFile,
    bool? panelClosed,
    bool? panelCollapsed,
    bool? panelScrollInProgress,
  }) {
    return WallpaperDetailLoaded(
      entity: entity ?? this.entity,
      views: views ?? this.views,
      viewsLoading: viewsLoading ?? this.viewsLoading,
      viewsError: viewsError,
      colors: colors ?? this.colors,
      accent: accent ?? this.accent,
      colorChanged: colorChanged ?? this.colorChanged,
      screenshotTaken: screenshotTaken ?? this.screenshotTaken,
      imageFile: imageFile ?? this.imageFile,
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
    viewsError,
    colors,
    accent,
    colorChanged,
    screenshotTaken,
    imageFile,
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
