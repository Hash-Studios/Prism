/// Whether [current] is lower than [minimum], comparing dotted versions part by part.
/// A part that is not a number counts as 0.
bool isVersionOlder(String current, String minimum) {
  final List<int> a = _parts(current);
  final List<int> b = _parts(minimum);
  final int length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final int left = i < a.length ? a[i] : 0;
    final int right = i < b.length ? b[i] : 0;
    if (left != right) return left < right;
  }
  return false;
}

List<int> _parts(String version) => version.split('.').map((part) => int.tryParse(part) ?? 0).toList(growable: false);
