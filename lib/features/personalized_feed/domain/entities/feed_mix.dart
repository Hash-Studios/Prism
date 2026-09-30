/// How far the home feed reaches outside the user's taste.
enum FeedMix {
  familiar('Familiar', exploreEvery: 8),
  balanced('Balanced', exploreEvery: 5),
  adventurous('Adventurous', exploreEvery: 3);

  const FeedMix(this.label, {required this.exploreEvery});

  final String label;

  /// Every n-th feed slot goes to a wallpaper outside the user's taste.
  final int exploreEvery;

  /// Reads a stored value, including the old 'creators' and 'discovery' names.
  static FeedMix parse(String? raw) => switch (raw?.trim().toLowerCase()) {
    'familiar' || 'creators' => FeedMix.familiar,
    'adventurous' || 'discovery' => FeedMix.adventurous,
    _ => FeedMix.balanced,
  };
}
