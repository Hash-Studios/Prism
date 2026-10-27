import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'wallpaper_position_event.j.dart';
part 'wallpaper_position_state.j.dart';
part 'wallpaper_position_bloc.j.freezed.dart';

@injectable
class WallpaperPositionBloc extends Bloc<WallpaperPositionEvent, WallpaperPositionState> {
  WallpaperPositionBloc(this._repository) : super(WallpaperPositionState.initial()) {
    on<_Started>(_onStarted);
    on<_FitChanged>(
      (event, emit) => emit(
        state.copyWith(
          placement: state.placement.copyWith(fit: event.fit),
          syncToken: state.syncToken + 1,
        ),
      ),
    );
    on<_Moved>(
      (event, emit) => emit(
        state.copyWith(
          placement: state.placement.copyWith(dx: event.dx, dy: event.dy, zoom: event.zoom),
        ),
      ),
    );
    on<_DimChanged>((event, emit) => emit(state.copyWith(placement: state.placement.copyWith(dim: event.dim))));
    on<_PreviewModeChanged>(
      (event, emit) => emit(state.copyWith(placement: state.placement.copyWith(previewMode: event.mode))),
    );
    on<_ResetRequested>(
      (event, emit) => emit(
        state.copyWith(
          placement: WallpaperPlacement(previewMode: state.placement.previewMode),
          syncToken: state.syncToken + 1,
        ),
      ),
    );
    on<_DoneRequested>(_onDoneRequested);
  }

  final WallpaperPositionRepository _repository;

  Future<void> _onStarted(_Started event, Emitter<WallpaperPositionState> emit) async {
    emit(WallpaperPositionState.initial());
    unawaited(analytics.track(WallpaperPositionOpenedEvent(source: event.entryPoint ?? 'unknown')));
    try {
      final PlacementSource source = await _repository.load(event.imageUrl);
      if (isClosed) {
        source.image.dispose();
        return;
      }
      emit(state.copyWith(status: WallpaperPositionStatus.ready, source: source));
    } catch (error, stackTrace) {
      logger.w('WallpaperPositionBloc: could not load the wallpaper', error: error, stackTrace: stackTrace);
      if (!isClosed) emit(state.copyWith(status: WallpaperPositionStatus.failed));
    }
  }

  Future<void> _onDoneRequested(_DoneRequested event, Emitter<WallpaperPositionState> emit) async {
    final PlacementSource? source = state.source;
    if (source == null || state.status != WallpaperPositionStatus.ready) return;
    final WallpaperPlacement placement = state.placement;
    emit(state.copyWith(status: WallpaperPositionStatus.rendering));
    try {
      final File file = await _repository.render(source, placement, event.outputSize);
      if (isClosed) {
        await PlacedWallpaper(path: file.path, placement: placement).discard();
        return;
      }
      emit(
        state.copyWith(
          status: WallpaperPositionStatus.ready,
          placed: PlacedWallpaper(path: file.path, placement: placement),
          placedToken: state.placedToken + 1,
        ),
      );
    } catch (error, stackTrace) {
      logger.e('WallpaperPositionBloc: could not render the wallpaper', error: error, stackTrace: stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: WallpaperPositionStatus.ready, renderErrorToken: state.renderErrorToken + 1));
      }
    }
  }

  @override
  Future<void> close() {
    state.source?.image.dispose();
    return super.close();
  }
}
