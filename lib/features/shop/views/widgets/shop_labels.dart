import 'package:Prism/core/coins/economy_config.dart';

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Nov 30" for the day a limited item stops selling, or null when the config has no valid date.
String? shopUntilLabel() {
  final DateTime? until = EconomyConfig.current.flags.foundersUntilAt;
  return until == null ? null : '${_months[until.month - 1]} ${until.day}';
}
