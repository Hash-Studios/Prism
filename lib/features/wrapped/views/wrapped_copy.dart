import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';

/// Everything a card says. The share image renders outside the widget tree, so the strings are resolved up front.
class WrappedCopy {
  const WrappedCopy({
    required this.kicker,
    required this.display,
    required this.body,
    this.since,
    this.swatches = const <Color>[],
    this.rows = const <(String, String)>[],
  });

  final String kicker;
  final String display;
  final String body;
  final String? since;
  final List<Color> swatches;

  /// Summary lines: a stat's label and its value.
  final List<(String, String)> rows;

  /// What a screen reader announces for the card.
  String get semantics => <String>[
    kicker,
    if (rows.isEmpty) display,
    if (body.isNotEmpty) body,
    for (final (String label, String value) in rows) '$label: $value',
    ?since,
  ].join('. ');
}

WrappedCopy wrappedCopy(AppLocalizations l10n, String locale, WrappedYear year, WrappedCard card) {
  final String y = '${year.year}';
  final String n = NumberFormat.decimalPattern(locale).format(card.value);
  final String? since = card.since == null ? null : l10n.wrappedSince(DateFormat.MMMd(locale).format(card.since!));
  String colour(int i) => prismPaletteColorDisplayName(card.colours[i], l10n);
  final String creatorName = card.creator == null
      ? ''
      : (card.creator!.name.isNotEmpty ? card.creator!.name : '@${card.creator!.username}');
  return switch (card.kind) {
    WrappedCardKind.intro => WrappedCopy(
      kicker: l10n.wrappedTitle(y),
      display: l10n.wrappedIntroHeadline,
      body: l10n.wrappedIntroBody,
    ),
    WrappedCardKind.saves => WrappedCopy(
      kicker: l10n.wrappedSavesLabel,
      display: n,
      body: l10n.wrappedSavesBody(card.value, y),
    ),
    WrappedCardKind.colours => WrappedCopy(
      kicker: l10n.wrappedColoursLabel,
      display: colour(0),
      body: l10n.wrappedColoursBody(colour(0), colour(1), colour(2)),
      swatches: card.colours.map((c) => c.color).toList(),
    ),
    WrappedCardKind.creator => WrappedCopy(
      kicker: l10n.wrappedCreatorLabel,
      display: '@${card.creator!.username}',
      body: l10n.wrappedCreatorBody(card.value, creatorName),
    ),
    WrappedCardKind.streak => WrappedCopy(
      kicker: l10n.wrappedStreakLabel,
      display: l10n.wrappedDays(card.value),
      body: l10n.wrappedStreakBody(card.value),
      since: since,
    ),
    WrappedCardKind.ai => WrappedCopy(
      kicker: l10n.wrappedAiLabel,
      display: n,
      body: l10n.wrappedAiBody(card.value),
      since: since,
    ),
    WrappedCardKind.category => WrappedCopy(
      kicker: l10n.wrappedCategoryLabel,
      display: card.category,
      body: l10n.wrappedCategoryBody(card.value, card.category),
    ),
    WrappedCardKind.folders => WrappedCopy(
      kicker: l10n.wrappedFoldersLabel,
      display: n,
      body: l10n.wrappedFoldersBody(card.value),
      since: since,
    ),
    WrappedCardKind.onScreen => WrappedCopy(
      kicker: l10n.wrappedOnScreenLabel,
      display: n,
      body: l10n.wrappedOnScreenBody(card.value),
      since: since,
    ),
    WrappedCardKind.challenges => WrappedCopy(
      kicker: l10n.wrappedChallengesLabel,
      display: n,
      body: l10n.wrappedChallengesBody(card.value),
      since: since,
    ),
    WrappedCardKind.tips => WrappedCopy(
      kicker: l10n.wrappedTipsLabel,
      display: n,
      body: l10n.wrappedTipsBody(card.value),
      since: since,
    ),
    WrappedCardKind.summary => WrappedCopy(
      kicker: l10n.wrappedTitle(y),
      display: l10n.wrappedSummaryHeadline(y),
      body: '',
      rows: <(String, String)>[
        for (final WrappedCard stat in year.cards.where(_summarised).take(4))
          () {
            final WrappedCopy c = wrappedCopy(l10n, locale, year, stat);
            return (c.kicker, c.display);
          }(),
      ],
    ),
  };
}

bool _summarised(WrappedCard card) => card.kind != WrappedCardKind.intro && card.kind != WrappedCardKind.summary;
