enum WallDisplayMode {
  immersive,
  comfortable,
}

extension ParseToStringWD on WallDisplayMode {
  String toText() {
    switch (this) {
      case WallDisplayMode.comfortable:
        return "Comfortable Grid";
      case WallDisplayMode.immersive:
        return "Immersive List";
      default:
        return "";
    }
  }
}
