bool _looksLikeEmail(String value) => RegExp(r'^\S+@\S+\.\S+$').hasMatch(value);

/// The text to show for a creator: name, then username, then [fallback]. Never an email address.
String creatorLabel({required String name, required String username, required String fallback}) {
  for (final String candidate in <String>[name.trim(), username.trim()]) {
    if (candidate.isNotEmpty && !_looksLikeEmail(candidate)) return candidate;
  }
  return fallback;
}
