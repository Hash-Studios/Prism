const String fallbackCreatorLabel = 'Prism creator';

bool _looksLikeEmail(String value) => RegExp(r'^\S+@\S+\.\S+$').hasMatch(value);

/// The text to show for a creator: name, then username, then "Prism creator". Never an email address.
String creatorLabel({String name = '', String username = ''}) {
  for (final String candidate in <String>[name.trim(), username.trim()]) {
    if (candidate.isNotEmpty && !_looksLikeEmail(candidate)) return candidate;
  }
  return fallbackCreatorLabel;
}
