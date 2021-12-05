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

  String toText() {
    final text =
        toString().split('.').last.replaceAll('dateAdded', 'Date Added');
    return text[0].toUpperCase() + text.substring(1);
  }
}
