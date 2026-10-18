import 'dart:math';

class AnalyticsCorrelation {
  AnalyticsCorrelation._();

  static final Random _random = Random.secure();

  static String newId() =>
      List<String>.generate(4, (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0')).join();
}
