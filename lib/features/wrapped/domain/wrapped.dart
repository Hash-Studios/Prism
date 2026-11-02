import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';

/// Every card the server can build, in no particular order. The server decides which cards a user gets and in what
/// order; the app only drops a card it cannot show.
enum WrappedCardKind {
  intro,
  saves,
  colours,
  creator,
  streak,
  ai,
  category,
  folders,
  onScreen,
  challenges,
  tips,
  summary,
}

class WrappedCreator {
  const WrappedCreator({required this.username, required this.name, required this.photo});

  final String username;
  final String name;
  final String photo;
}

class WrappedCard {
  const WrappedCard({
    required this.kind,
    required this.heroUrl,
    this.value = 0,
    this.since,
    this.colours = const <PrismPaletteColor>[],
    this.category = '',
    this.creator,
    this.thumbs = const <String>[],
  });

  final WrappedCardKind kind;

  /// One of the user's own walls (a save, an AI wall or a folder cover), never stock art.
  final String heroUrl;
  final int value;

  /// The first day this stat has data, when that is after 1 January. The copy then says "Since", not "this year".
  final DateTime? since;
  final List<PrismPaletteColor> colours;
  final String category;
  final WrappedCreator? creator;

  /// The summary collage.
  final List<String> thumbs;

  /// The id the analytics events carry.
  String get id => kind.name;
}

class WrappedYear {
  const WrappedYear({required this.year, required this.through, required this.accents, required this.cards});

  final int year;
  final DateTime through;

  /// The user's top colours, most used first. Empty when the colours card did not make the cut.
  final List<PrismPaletteColor> accents;
  final List<WrappedCard> cards;
}

abstract interface class WrappedRepository {
  /// The signed-in user's Wrapped for [year], or null when they have none.
  Future<WrappedYear?> fetch(String uid, int year);
}

const int wrappedYear = 2026;
const int _minStatCards = 4;
const int _maxStatCards = 7;

/// Parses the server doc. Cards the app cannot show are dropped; a doc left with fewer than four stats is treated as no
/// Wrapped at all, so the user never sees a thin or zero recap.
WrappedYear? parseWrappedYear(Map<String, dynamic> data, {int year = wrappedYear}) {
  if (data['year'] != year || data['version'] != 1) return null;
  final Object? through = data['through'];
  final Object? rawCards = data['cards'];
  if (rawCards is! List) return null;
  final List<WrappedCard> cards = rawCards.whereType<Map<Object?, Object?>>().map(_card).nonNulls.toList();
  final List<WrappedCard> statCards = cards
      .where((c) => c.kind != WrappedCardKind.intro && c.kind != WrappedCardKind.summary)
      .toList();
  final int stats = statCards.length;
  if (stats < _minStatCards ||
      stats > _maxStatCards ||
      cards.length != stats + 2 ||
      cards.map((c) => c.kind).toSet().length != cards.length ||
      cards.first.kind != WrappedCardKind.intro ||
      cards.last.kind != WrappedCardKind.summary) {
    return null;
  }
  return WrappedYear(
    year: year,
    through: parseDateTime(through)?.toUtc() ?? DateTime.utc(year, 12),
    accents: _colours(data['accents']),
    cards: cards,
  );
}

WrappedCard? _card(Map<Object?, Object?> raw) {
  final WrappedCardKind? kind = WrappedCardKind.values.where((k) => k.name == raw['id']).firstOrNull;
  if (kind == null) return null;
  final Object? hero = raw['hero'];
  final String heroUrl = hero is Map ? _string(hero['url']) : '';
  final int value = raw['value'] is int ? raw['value']! as int : 0;
  final Object? since = raw['since'];
  final WrappedCard card = WrappedCard(
    kind: kind,
    heroUrl: heroUrl,
    value: value,
    since: since is String ? DateTime.tryParse('${since}T00:00:00Z') : null,
    colours: _colours(raw['colours']),
    category: _string(raw['category']),
    creator: _creator(raw['creator']),
    thumbs: raw['thumbs'] is List
        ? (raw['thumbs']! as List).whereType<String>().where((t) => t.isNotEmpty).toList()
        : [],
  );
  final bool showable = switch (kind) {
    WrappedCardKind.intro => heroUrl.isNotEmpty,
    WrappedCardKind.summary => card.thumbs.isNotEmpty,
    WrappedCardKind.colours => card.colours.length == 3 && value > 0,
    WrappedCardKind.creator => card.creator != null && value > 0,
    WrappedCardKind.category => card.category.isNotEmpty && value > 0,
    _ => value > 0,
  };
  return showable ? card : null;
}

WrappedCreator? _creator(Object? raw) {
  if (raw is! Map) return null;
  final String username = _string(raw['username']);
  if (username.isEmpty) return null;
  return WrappedCreator(username: username, name: _string(raw['name']), photo: _string(raw['photo']));
}

List<PrismPaletteColor> _colours(Object? raw) => raw is List
    ? raw.map((id) => prismPalette.where((c) => c.id == id).firstOrNull).nonNulls.toList()
    : const <PrismPaletteColor>[];

String _string(Object? value) => value is String ? value.trim() : '';
