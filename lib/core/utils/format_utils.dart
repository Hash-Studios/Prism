/// `999`, `1.2K`, `12K`, `1.2M`.
String formatCompactCount(int count) {
  String compact(double value, String suffix) => '${value.toStringAsFixed(value >= 10 ? 0 : 1)}$suffix';
  if (count >= 1000000) return compact(count / 1000000, 'M');
  if (count >= 1000) return compact(count / 1000, 'K');
  return '$count';
}

/// Decimal megabytes with two digits, e.g. `2.45 MB`.
String formatMegabytes(int bytes) => '${(bytes / 1000000).toStringAsFixed(2)} MB';
