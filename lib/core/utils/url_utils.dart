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
