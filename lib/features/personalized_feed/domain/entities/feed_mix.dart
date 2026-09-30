enum FeedMix {
  balanced('Balanced'),
  creators('Creators'),
  discovery('Discovery');

  const FeedMix(this.label);

  final String label;

  static FeedMix fromName(String name) =>
      FeedMix.values.firstWhere((FeedMix mix) => mix.name == name, orElse: () => FeedMix.balanced);
}
