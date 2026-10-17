part of 'drops_bloc.j.dart';

@freezed
abstract class DropsState with _$DropsState {
  const factory DropsState({
    required LoadStatus status,
    required DateTime now,
    DropEntity? drop,
    @Default(<DropEntity>[]) List<DropEntity> past,
    @Default(<String, DropUnlock>{}) Map<String, DropUnlock> unlocked,

    /// The wall id being unlocked, or [DropsBloc.packKey] for the pack.
    String? busyKey,

    /// The newest unlock reply. The page toasts it once.
    DropUnlockResult? lastResult,
  }) = _DropsState;

  const DropsState._();

  factory DropsState.initial() => DropsState(status: LoadStatus.initial, now: DateTime.now());

  bool get isLive => drop?.isLiveAt(now) ?? false;

  List<DropWall> get lockedWalls =>
      (drop?.walls ?? const <DropWall>[]).where((w) => !unlocked.containsKey(w.id)).toList(growable: false);

  int get unlockedCount => (drop?.walls.length ?? 0) - lockedWalls.length;

  /// Past Drops with at least one wall the user owns, newest first.
  List<DropEntity> get vault => past.where((d) => d.walls.any((w) => unlocked.containsKey(w.id))).toList();
}
