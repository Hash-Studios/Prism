enum Purity {
  onlySfw,
  onlySketchy,
  onlyNsfw,
  sfwAndSketchy,
  sfwAndNsfw,
  sketchyAndNsfw,
  all
}

extension ParseToIntP on Purity {
  String toIntString() {
    switch (this) {
      case Purity.onlySfw:
        return '100';
      case Purity.onlySketchy:
        return '010';
      case Purity.onlyNsfw:
        return '001';
      case Purity.sfwAndSketchy:
        return '110';
      case Purity.sfwAndNsfw:
        return '101';
      case Purity.sketchyAndNsfw:
        return '011';
      case Purity.all:
        return '111';
      default:
        return '111';
    }
  }
}
