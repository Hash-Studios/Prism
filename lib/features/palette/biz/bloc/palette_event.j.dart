part of 'palette_bloc.j.dart';

@freezed
abstract class PaletteEvent with _$PaletteEvent {
  const factory PaletteEvent.paletteRequested({required String imageUrl}) = _PaletteRequested;
  const factory PaletteEvent.paletteCleared() = _PaletteCleared;
}
