import 'dart:async';

import 'package:Prism/features/theme_mode/views/widgets/spooky_decor.dart';

/// Pins the Halloween season clock after the season, so the home carousel does not change with the real date.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  spookyClock = () => DateTime(2026, 12);
  await testMain();
}
