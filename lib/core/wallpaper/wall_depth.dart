/// How the iOS Lock Screen Depth Effect treats a wall, read from `walls.depth.tier`.
enum WallDepthTier {
  /// iOS puts the subject in front of the clock by itself.
  auto,

  /// The user turns it on in the Lock Screen editor: ••• then Depth Effect.
  menu,

  /// iOS cannot use the Depth Effect on this wall.
  none;

  bool get supportsDepth => this != none;

  /// Null for a missing or unknown value, which means the wall was not checked.
  static WallDepthTier? parse(Object? value) {
    for (final tier in values) {
      if (tier.name == value) return tier;
    }
    return null;
  }
}
