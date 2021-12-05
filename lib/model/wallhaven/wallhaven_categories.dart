enum Categories {
  onlyGeneral,
  onlyAnime,
  onlyPeople,
  generalAndAnime,
  generalAndPeople,
  animeAndPeople,
  all
}

extension ParseToIntC on Categories {
  String toIntString() {
    switch (this) {
      case Categories.onlyGeneral:
        return '100';
      case Categories.onlyAnime:
        return '010';
      case Categories.onlyPeople:
        return '001';
      case Categories.generalAndAnime:
        return '110';
      case Categories.generalAndPeople:
        return '101';
      case Categories.animeAndPeople:
        return '011';
      case Categories.all:
        return '111';
      default:
        return '111';
    }
  }
}
