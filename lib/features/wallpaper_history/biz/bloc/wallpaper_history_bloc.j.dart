import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'wallpaper_history_event.j.dart';
part 'wallpaper_history_state.j.dart';
part 'wallpaper_history_bloc.j.freezed.dart';

@injectable
class WallpaperHistoryBloc extends Bloc<WallpaperHistoryEvent, WallpaperHistoryState> {
  WallpaperHistoryBloc(this._store) : super(WallpaperHistoryState.initial()) {
    on<_Started>((event, emit) => emit(state.copyWith(items: _store.items())));
    on<_Cleared>(_onCleared);
    on<_Removed>(_onRemoved);
    on<_Restored>(_onRestored);
  }

  final WallpaperHistoryStore _store;

  Future<void> _onCleared(_Cleared event, Emitter<WallpaperHistoryState> emit) async {
    await _store.clear();
    emit(state.copyWith(items: _store.items()));
  }

  Future<void> _onRemoved(_Removed event, Emitter<WallpaperHistoryState> emit) async {
    await _store.remove(event.id);
    emit(state.copyWith(items: _store.items()));
  }

  Future<void> _onRestored(_Restored event, Emitter<WallpaperHistoryState> emit) async {
    await _store.record(event.item);
    emit(state.copyWith(items: _store.items()));
  }
}
