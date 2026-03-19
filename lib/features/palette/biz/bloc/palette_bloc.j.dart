import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/palette/domain/entities/palette_entity.dart';
import 'package:Prism/features/palette/domain/usecases/generate_palette_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'palette_event.j.dart';
part 'palette_state.j.dart';
part 'palette_bloc.j.freezed.dart';

@lazySingleton
class PaletteBloc extends Bloc<PaletteEvent, PaletteState> {
  PaletteBloc(this._generatePaletteUseCase) : super(PaletteState.initial()) {
    on<_PaletteRequested>(_onPaletteRequested);
    on<_PaletteCleared>(_onPaletteCleared);
  }

  final GeneratePaletteUseCase _generatePaletteUseCase;

  Future<void> _onPaletteRequested(_PaletteRequested event, Emitter<PaletteState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _generatePaletteUseCase(GeneratePaletteParams(imageUrl: event.imageUrl));

    result.fold(
      onSuccess: (palette) => emit(state.copyWith(status: LoadStatus.success, palette: palette, failure: null)),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
  }

  void _onPaletteCleared(_PaletteCleared event, Emitter<PaletteState> emit) {
    emit(PaletteState.initial());
  }
}
