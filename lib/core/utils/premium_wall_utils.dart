bool isPremiumWall(List<String> premiumCollections, List<Object?> wallCollections) {
  for (final Object? element in wallCollections) {
    final String value = element.toString().trim();
    if (premiumCollections.contains(value)) {
      return true;
    }
  }
  return false;
}
