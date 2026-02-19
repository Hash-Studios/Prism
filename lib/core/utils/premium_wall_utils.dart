bool isPremiumWall(List<String> premiumCollections, List<dynamic> wallCollections) {
  for (final dynamic element in wallCollections) {
    final String value = element.toString().trim();
    if (premiumCollections.contains(value)) {
      return true;
    }
  }
  return false;
}
