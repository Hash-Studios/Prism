enum WallThumbQuality {
  high,
  low,
}

extension ParseToStringWT on WallThumbQuality {
  String toText() {
    switch (this) {
      case WallThumbQuality.high:
        return "High";
      case WallThumbQuality.low:
        return "Low";
      default:
        return "";
    }
  }
}
