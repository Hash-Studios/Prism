bool isValidNetworkUrl(String? rawUrl) {
  final String candidate = (rawUrl ?? '').trim();
  if (candidate.isEmpty) {
    return false;
  }
  final Uri? uri = Uri.tryParse(candidate);
  if (uri == null) {
    return false;
  }
  final String scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}

/// File name for a downloaded wallpaper: the last path segment of [link] without its extension.
/// The native side adds the extension, so keeping `.jpeg` here gave `name.jpeg.jpg`.
String downloadBaseName(String link) {
  final Uri? uri = Uri.tryParse(link);
  final String last = uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : link.split('/').last;
  final int dot = last.lastIndexOf('.');
  return dot > 0 ? last.substring(0, dot) : last;
}
