enum Purity {
  onlySfw,
  onlySketchy,
  onlyNsfw,
  sfwAndSketchy,
  sfwAndNsfw,
  sketchyAndNsfw,
  all
}

Purity fromIntStringP(String value) {
  switch (value) {
    case '100':
      return Purity.onlySfw;
    case '010':
      return Purity.onlySketchy;
    case '001':
      return Purity.onlyNsfw;
    case '110':
      return Purity.sfwAndSketchy;
    case '011':
      return Purity.sketchyAndNsfw;
    case '101':
      return Purity.sfwAndNsfw;
    case '111':
      return Purity.all;
    default:
      return Purity.all;
  }
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

  String toShortString() {
    switch (this) {
      case Purity.onlySfw:
        return 'SFW';
      case Purity.onlySketchy:
        return 'Sketchy';
      case Purity.onlyNsfw:
        return 'NSFW';
      case Purity.sfwAndSketchy:
        return 'SFW & Sketchy';
      case Purity.sfwAndNsfw:
        return 'SFW & NSFW';
      case Purity.sketchyAndNsfw:
        return 'Sketchy & NSFW';
      case Purity.all:
        return 'All';
      default:
        return 'All';
    }
  }
}
