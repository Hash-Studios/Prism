part of 'palette_bloc.j.dart';

@freezed
abstract class PaletteState with _$PaletteState {
  const factory PaletteState({
    required LoadStatus status,
    required PaletteEntity palette,
    Failure? failure,
  }) = _PaletteState;

  factory PaletteState.initial() => const PaletteState(
        status: LoadStatus.initial,
        palette: PaletteEntity.empty,
      );
}
