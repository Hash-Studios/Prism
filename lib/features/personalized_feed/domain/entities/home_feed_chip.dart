/// The views of the home feed, in chip rail order.
enum HomeFeedChip {
  forYou('For you'),
  latest('Latest'),
  following('Following'),
  popular('Popular');

  const HomeFeedChip(this.label);

  final String label;
}
