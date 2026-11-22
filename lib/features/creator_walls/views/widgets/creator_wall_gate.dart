import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/creator_walls/data/creator_wall_unlocks.dart';
import 'package:flutter/widgets.dart';

/// Builds [builder] with the user's [CreatorWallAccess] to [wall], and again when an unlock lands or a marker is read.
/// A null [wall] (not a Prism wall) is [CreatorWallAccess.free].
class CreatorWallGate extends StatelessWidget {
  const CreatorWallGate({required this.wall, required this.builder, this.unlocks, super.key});

  final PrismWallpaper? wall;
  final Widget Function(BuildContext context, CreatorWallAccess access) builder;

  @visibleForTesting
  final CreatorWallUnlocks? unlocks;

  @override
  Widget build(BuildContext context) {
    final CreatorWallUnlocks store = unlocks ?? CreatorWallUnlocks.instance;
    return ValueListenableBuilder<int>(
      valueListenable: store.changes,
      builder: (BuildContext context, _, _) {
        final PrismWallpaper? priced = wall;
        return builder(context, priced == null ? CreatorWallAccess.free : store.accessFor(priced));
      },
    );
  }
}

extension CreatorWallAccessX on CreatorWallAccess {
  /// Download and set wait for an unlock.
  bool get locked => this == CreatorWallAccess.locked || this == CreatorWallAccess.checking;
}
