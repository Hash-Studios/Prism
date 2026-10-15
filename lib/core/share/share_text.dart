final RegExp _emailAddress = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');

/// Text that leaves the app (a share card, a link preview title) must never hold an email address. A wallpaper can
/// carry one as its creator name when the creator has no display name. Returns null for empty text and for text with
/// an email in it, so the caller falls back to its plain default.
String? shareSafeText(String? text) {
  final String trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty || _emailAddress.hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}
