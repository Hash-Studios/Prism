import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

/// A wall that was the Wall of the Day on [date].
class WotdPastPick {
  const WotdPastPick({required this.date, required this.wallpaper});

  final DateTime date;
  final PrismWallpaper wallpaper;
}
