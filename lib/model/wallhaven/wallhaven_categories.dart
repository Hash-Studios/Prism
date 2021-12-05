enum Categories {
  onlyGeneral,
  onlyAnime,
  onlyPeople,
  generalAndAnime,
  generalAndPeople,
  animeAndPeople,
  all
}

Categories fromIntStringC(String value) {
  switch (value) {
    case '100':
      return Categories.onlyGeneral;
    case '010':
      return Categories.onlyAnime;
    case '001':
      return Categories.onlyPeople;
    case '110':
      return Categories.generalAndAnime;
    case '101':
      return Categories.generalAndPeople;
    case '011':
      return Categories.animeAndPeople;
    case '111':
      return Categories.all;
    default:
      return Categories.all;
  }
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

  String toShortString() {
    switch (this) {
      case Categories.onlyGeneral:
        return 'General';
      case Categories.onlyAnime:
        return 'Anime';
      case Categories.onlyPeople:
        return 'People';
      case Categories.generalAndAnime:
        return 'General & Anime';
      case Categories.generalAndPeople:
        return 'General & People';
      case Categories.animeAndPeople:
        return 'Anime & People';
      case Categories.all:
        return 'All';
      default:
        return 'All';
    }
  }
}
