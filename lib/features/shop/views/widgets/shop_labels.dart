import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// "Nov 30" for the day a limited item stops selling, or null when the config has no valid date.
String? shopUntilLabel(AppLocalizations l10n) {
  final DateTime? until = EconomyConfig.current.flags.foundersUntilAt;
  return until == null ? null : DateFormat.MMMd(l10n.localeName).format(until);
}
