enum Order {
  desc,
  asc,
}

extension ParseToStringO on Order {
  String toShortString() {
    return toString().split('.').last;
  }
}
