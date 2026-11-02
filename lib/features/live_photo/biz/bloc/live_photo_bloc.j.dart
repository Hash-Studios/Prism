import 'dart:ui' show Color, Size;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/domain/repositories/live_photo_repository.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_photo_event.j.dart';
part 'live_photo_state.j.dart';
part 'live_photo_bloc.j.freezed.dart';

class LivePhotoBloc extends Bloc<LivePhotoEvent, LivePhotoState> {
  LivePhotoBloc(
    this._repository, {
    required this.wallId,
    required this.resolveSource,
    required bool isPro,
    this.canExport,
    this.depthMapUrl,
    Map<String, DateTime> unlockedStyles = const <String, DateTime>{},
  }) : super(
         LivePhotoState(
           phase: LivePhotoPhase.picking,
           styles: livePhotoStylesFor(hasDepthMap: depthMapUrl != null),
           style: MotionStyle.drift,
           isPro: isPro,
           unlockedStyles: unlockedStyles,
         ),
       ) {
    on<_StyleSelected>((event, emit) {
      if (state.phase == LivePhotoPhase.picking && state.styles.contains(event.style)) {
        emit(state.copyWith(style: event.style));
      }
    });
    on<_AccessChanged>((event, emit) {
      emit(state.copyWith(isPro: event.isPro, unlockedStyles: event.unlockedStyles));
      if (state.phase == LivePhotoPhase.exporting && state.isLocked(state.style)) {
        add(const LivePhotoEvent.cancelRequested());
      }
    });
    on<_ExportRequested>(_onExport);
    on<_Progressed>((event, emit) {
      if (state.phase == LivePhotoPhase.exporting) emit(state.copyWith(progress: event.fraction));
    });
    on<_CancelRequested>(_onCancel);
    on<_Reset>((event, emit) {
      if (state.phase != LivePhotoPhase.exporting) emit(state.copyWith(phase: LivePhotoPhase.picking, outcome: null));
    });
  }

  final LivePhotoRepository _repository;
  final String wallId;
  final String? depthMapUrl;

  final Future<String?> Function() resolveSource;
  final bool Function(MotionStyle style)? canExport;
  bool _closing = false;
  int _exportGeneration = 0;

  Future<void> _onExport(_ExportRequested event, Emitter<LivePhotoState> emit) async {
    if (_closing ||
        state.phase != LivePhotoPhase.picking ||
        state.isLocked(state.style) ||
        !(canExport?.call(state.style) ?? true)) {
      return;
    }
    final int generation = ++_exportGeneration;
    final MotionStyle style = state.style;
    final LiveWallpaperStyleValue styleValue = _styleValue(style);
    emit(state.copyWith(phase: LivePhotoPhase.exporting, progress: 0, cancelling: false, outcome: null));
    analytics.track(LivePhotoExportStartedEvent(style: styleValue));
    final String? source;
    try {
      source = await resolveSource();
      if (_closing || emit.isDone) return;
    } catch (_) {
      if (_closing || emit.isDone) return;
      analytics.track(LivePhotoExportFailedEvent(style: styleValue, reason: 'source_unavailable'));
      emit(
        state.copyWith(
          phase: LivePhotoPhase.failed,
          cancelling: false,
          outcome: const LiveExportFailed(LiveExportFailure.sourceUnavailable),
        ),
      );
      return;
    }
    if (source == null) {
      analytics.track(LivePhotoExportCancelledEvent(style: styleValue));
      emit(state.copyWith(phase: LivePhotoPhase.picking, cancelling: false));
      return;
    }
    if (state.cancelling || state.isLocked(style) || !(canExport?.call(style) ?? true)) {
      analytics.track(LivePhotoExportCancelledEvent(style: styleValue));
      emit(state.copyWith(phase: LivePhotoPhase.picking, cancelling: false));
      return;
    }
    final LiveExport export = LiveExport(wallId: wallId, style: style, sizePx: event.sizePx);
    final LiveExportOutcome outcome = await _repository.export(
      export,
      imageUrl: source,
      tint: event.tint,
      depthMapUrl: depthMapUrl,
      onProgress: (fraction) {
        if (!_closing && !isClosed && !emit.isDone && generation == _exportGeneration) {
          add(LivePhotoEvent.progressed(fraction));
        }
      },
    );
    if (_closing || emit.isDone) return;
    switch (outcome) {
      case LiveExportSaved():
        analytics.track(LivePhotoExportDoneEvent(style: styleValue, durationMs: export.duration.inMilliseconds));
        emit(state.copyWith(phase: LivePhotoPhase.saved, progress: 1, cancelling: false, outcome: outcome));
      case LiveExportCancelled():
        analytics.track(LivePhotoExportCancelledEvent(style: styleValue));
        emit(state.copyWith(phase: LivePhotoPhase.picking, cancelling: false, outcome: null));
      case LiveExportRefused(:final bool restricted):
        analytics.track(
          LivePhotoExportFailedEvent(
            style: styleValue,
            reason: restricted ? 'permission_restricted' : 'permission_denied',
          ),
        );
        emit(state.copyWith(phase: LivePhotoPhase.refused, cancelling: false, outcome: outcome));
      case LiveExportTimedOut():
        analytics.track(LivePhotoExportFailedEvent(style: styleValue, reason: 'timed_out'));
        emit(state.copyWith(phase: LivePhotoPhase.failed, cancelling: false, outcome: outcome));
      case LiveExportFailed(:final LiveExportFailure reason):
        analytics.track(LivePhotoExportFailedEvent(style: styleValue, reason: _snakeCase(reason.name)));
        emit(state.copyWith(phase: LivePhotoPhase.failed, cancelling: false, outcome: outcome));
    }
  }

  Future<void> _onCancel(_CancelRequested event, Emitter<LivePhotoState> emit) async {
    if (state.phase != LivePhotoPhase.exporting || state.cancelling) return;
    emit(state.copyWith(cancelling: true));
    await _repository.cancel();
  }

  @override
  Future<void> close() async {
    _closing = true;
    _exportGeneration++;
    if (state.phase == LivePhotoPhase.exporting) await _repository.cancel();
    return super.close();
  }

  static LiveWallpaperStyleValue _styleValue(MotionStyle style) => switch (style) {
    MotionStyle.drift => LiveWallpaperStyleValue.drift,
    MotionStyle.breathe => LiveWallpaperStyleValue.breathe,
    MotionStyle.ripple => LiveWallpaperStyleValue.ripple,
    MotionStyle.shimmer => LiveWallpaperStyleValue.shimmer,
    MotionStyle.depth => LiveWallpaperStyleValue.threeD,
  };

  static String _snakeCase(String name) =>
      name.replaceAllMapped(RegExp('[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');
}
