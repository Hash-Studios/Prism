import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

extension NavTabView on NavTab {
  /// The same glyph in both states, as on the current app. The active tab shows through the circle and the full ink.
  IconData get icon => switch (this) {
    NavTab.home => Icons.home_rounded,
    NavTab.search => Icons.search_rounded,
    NavTab.rewards => Icons.card_giftcard_rounded,
    NavTab.collection => Icons.grid_view_rounded,
  };

  NavTabValue get analyticsValue => switch (this) {
    NavTab.home => NavTabValue.home,
    NavTab.search => NavTabValue.search,
    NavTab.rewards => NavTabValue.streak,
    NavTab.collection => NavTabValue.collection,
  };

  String label(BuildContext context) => switch (this) {
    NavTab.home => context.l10n.wallpaperNavHome,
    NavTab.search => context.l10n.wallpaperNavSearch,
    NavTab.rewards => context.l10n.wallpaperNavRewards,
    NavTab.collection => context.l10n.wallpaperNavCollections,
  };
}
