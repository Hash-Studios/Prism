enum Sorting {
  dateAdded,
  relevance,
  random,
  views,
  favorites,
  toplist,
}

extension ParseToStringS on Sorting {
  String toShortString() {
    return toString().split('.').last.replaceAll('dateAdded', 'date_added');
  }
}
