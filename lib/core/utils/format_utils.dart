import 'package:Prism/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Decimal megabytes with locale-aware digits and decimal separator, e.g. `2.45 MB`.
String formatMegabytes(int bytes, AppLocalizations l10n) {
  final String size = NumberFormat('0.00', l10n.localeName).format(bytes / 1000000);
  return l10n.coreFileSizeMegabytes(size);
}
