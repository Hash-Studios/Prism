/// The views of the home feed, in tab order.
enum HomeFeedChip {
  forYou('For you'),
  following('Following'),
  trending('Trending'),
  latest('Latest'),
  popular('Popular');

  const HomeFeedChip(this.label);

  final String label;
}
