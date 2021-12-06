enum Purity { onlySfw, onlySketchy, all }

Purity fromIntStringP(String value) {
  switch (value) {
    case '100':
      return Purity.onlySfw;
    case '010':
      return Purity.onlySketchy;
    case '110':
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
      case Purity.all:
        return '110';
      default:
        return '110';
    }
  }

  String toShortString() {
    switch (this) {
      case Purity.onlySfw:
        return 'SFW';
      case Purity.onlySketchy:
        return 'Sketchy';
      case Purity.all:
        return 'All';
      default:
        return 'All';
    }
  }
}
