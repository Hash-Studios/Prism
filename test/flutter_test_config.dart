import 'dart:async';

import 'package:Prism/features/theme_mode/seasonal_themes.dart';

/// Pins the season clock after the seasons, so the home carousel does not change with the real date.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  seasonClock = () => DateTime(2026, 12);
  await testMain();
}
