import 'dart:math' as math;

import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/wall_search_terms.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';

/// A Prism wall and its stored `searchTerms`, which hold its tags, category and Cloud Vision labels.
typedef PhotoCandidate = ({PrismWallpaper wall, List<String> terms});

/// The search terms of [query]'s labels and category, in the form the backend stores in `walls.searchTerms`.
List<String> photoQueryTerms(PhotoQuery query) => searchTermsOf(<String>[...query.labels, ?query.category].join(' '));

/// [candidates] ordered by how well they match [query], best first, at most [limit].
///
/// Palette closeness and label overlap count half each. With no labels, palette closeness alone decides. A wall
/// without colours has closeness 0. Ties keep the order of [candidates].
List<PrismWallpaper> rankPhotoMatches(PhotoQuery query, List<PhotoCandidate> candidates, {int limit = 12}) {
  final List<String> terms = photoQueryTerms(query);
  final List<({PrismWallpaper wall, double score, int order})> scored =
      <({PrismWallpaper wall, double score, int order})>[
        for (final (int i, PhotoCandidate candidate) in candidates.indexed)
          (
            wall: candidate.wall,
            score: terms.isEmpty
                ? paletteCloseness(query.palette, candidate.wall.colors)
                : 0.5 * paletteCloseness(query.palette, candidate.wall.colors) +
                      0.5 * terms.where(candidate.terms.contains).length / terms.length,
            order: i,
          ),
      ];
  scored.sort((a, b) {
    final int byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });
  return <PrismWallpaper>[for (final match in scored.take(limit)) match.wall];
}

/// From 0 to 1: 1 when the wall has the photo's colours in the same shares, 0 when the wall has no known colour.
///
/// A wall stores up to three colour ids, the largest first, without shares. They count 1, then 0.6 / 0.4, then
/// 0.5 / 0.3 / 0.2. Half the score is the share overlap: for each colour, the smaller of its two shares, summed. It
/// rewards the same colours in the same order of size. The other half is 1 minus the mean of two directed Lab
/// distances, each colour to the nearest colour on the other side, weighted by its share, where black to white is 1.
/// It gives near colours, such as blue and teal, part of the score that the overlap gives only to exact ones.
double paletteCloseness(List<PaletteShare> photo, List<String>? wallColorIds) {
  final List<PaletteShare> wall = _wallShares(wallColorIds);
  if (photo.isEmpty || wall.isEmpty) return 0;
  double shareOf(List<PaletteShare> palette, PrismPaletteColor color) =>
      palette.where((entry) => entry.color == color).fold(0, (sum, entry) => sum + entry.share);
  final double overlap = photo.fold(0, (sum, a) => sum + math.min(a.share, shareOf(wall, a.color)));
  double directed(List<PaletteShare> from, List<PaletteShare> to) =>
      from.fold(0, (sum, a) => sum + a.share * to.map((b) => paletteDistance(a.color, b.color)).reduce(math.min));
  final double nearness = (1 - (directed(photo, wall) + directed(wall, photo)) / 200).clamp(0, 1);
  return 0.5 * overlap + 0.5 * nearness;
}

const List<List<double>> _rankShares = <List<double>>[
  <double>[1],
  <double>[0.6, 0.4],
  <double>[0.5, 0.3, 0.2],
];

List<PaletteShare> _wallShares(List<String>? ids) {
  final List<PrismPaletteColor> colors = <PrismPaletteColor>[
    for (final String id in ids ?? const <String>[]) ?paletteColorById(id),
  ].take(3).toList();
  if (colors.isEmpty) return const <PaletteShare>[];
  final List<double> shares = _rankShares[colors.length - 1];
  return <PaletteShare>[
    for (final (int i, PrismPaletteColor color) in colors.indexed) (color: color, share: shares[i]),
  ];
}
