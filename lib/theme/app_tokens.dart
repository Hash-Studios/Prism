import 'package:flutter/material.dart';

/// Hard-coded semantic color tokens for Prism UI chrome.
///
/// Prefer [Theme.of(context).colorScheme] for surface/content colors that
/// change with the active theme. Use [PrismColors] only for values that must
/// remain constant across all themes — e.g. brand accents and overlay helpers.
// ignore: avoid_classes_with_only_static_members
abstract final class PrismColors {
  /// Status: something went well (approved, saved, earned). Pair it with an icon or a label.
  static const Color success = Color(0xFF2FBF71);

  /// Status: needs attention (pending, streak at risk). Pair it with an icon or a label.
  static const Color warning = Color(0xFFFFB454);

  /// Foreground color on primary / app-bar surfaces.
  /// Always white so that content stays legible regardless of the active theme.
  static const Color onPrimary = Colors.white;
}

/// The spacing scale. Every gap and padding in new UI comes from here.
abstract final class PrismSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Left and right page margin.
  static const double page = 20;

  /// Space to keep clear at the bottom of a tab page, above the floating bottom bar.
  static const double bottomBarClearance = 120;

  static const EdgeInsets pageInsets = EdgeInsets.symmetric(horizontal: page);
}

/// The corner radius scale. A nested surface uses the step below its parent so corners stay concentric.
abstract final class PrismRadius {
  /// Thumbnails, small tags.
  static const double xs = 8;

  /// Tiles, inputs inside cards, icon tiles.
  static const double sm = 12;

  /// Inputs, small cards, dialogs' inner content.
  static const double md = 16;

  /// Cards.
  static const double lg = 20;

  /// Sheets and dialogs.
  static const double xl = 28;

  /// Buttons, chips, pills.
  static const double pill = 999;
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xl));
}

/// Font family name constants.
///
/// Keep font strings in one place so renaming a family only requires one edit.
abstract final class PrismFonts {
  static const String proximaNova = 'Proxima Nova';
  static const String fraunces = 'Fraunces';
  static const String roboto = 'Roboto';
}

/// Pre-built text styles for recurring chrome and editorial patterns.
///
/// Where a style must adapt to the active theme use the static helper methods
/// (which accept a [BuildContext]). Purely structural styles that do not vary
/// by theme are exposed as `const` values.
// ignore: avoid_classes_with_only_static_members
abstract final class PrismTextStyles {
  static TextStyle _base(BuildContext context, double size, FontWeight weight, {double alpha = 1, double? height}) {
    return TextStyle(
      fontFamily: PrismFonts.proximaNova,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha),
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// Hero line in Fraunces for onboarding, paywalls and big moments (34 w700).
  static TextStyle display(BuildContext context) => TextStyle(
    fontFamily: PrismFonts.fraunces,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -0.6,
    color: Theme.of(context).colorScheme.onSurface,
  );

  /// Button label (15 w600). The button sets the colour.
  static const TextStyle button = TextStyle(
    fontFamily: PrismFonts.proximaNova,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Page title (28 w700).
  static TextStyle screenTitle(BuildContext context) => _base(context, 28, FontWeight.w700, height: 1.1);

  /// Section heading (20 w700).
  static TextStyle sectionTitle(BuildContext context) => _base(context, 20, FontWeight.w700);

  /// Sheet headline (24 w700).
  static TextStyle sheetHeadline(BuildContext context) => _base(context, 24, FontWeight.w700);

  /// Card heading (16 w700).
  static TextStyle cardTitle(BuildContext context) => _base(context, 16, FontWeight.w700);

  /// Row and tile title (15 w600).
  static TextStyle rowTitle(BuildContext context) => _base(context, 15, FontWeight.w600);

  /// Body copy (14 w500, secondary text colour).
  static TextStyle body(BuildContext context) =>
      _base(context, 14, FontWeight.w500).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  /// Small supporting text (12 w500, secondary text colour).
  static TextStyle caption(BuildContext context) =>
      _base(context, 12, FontWeight.w500).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  /// Small label above a value (11 w700, tracked). The caller upper-cases the text.
  static TextStyle eyebrow(BuildContext context) => _base(
    context,
    11,
    FontWeight.w700,
  ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1.4);

  /// Big number in Fraunces.
  static TextStyle numeral(BuildContext context, double size) => TextStyle(
    fontFamily: PrismFonts.fraunces,
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.0,
    color: Theme.of(context).colorScheme.onSurface,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Brand wordmark ("prism") shown in the top app-bar.
  ///
  /// Uses the Fraunces variable font with the WONK axis set to maximum
  /// to achieve the characteristic Prism logo look.
  static const TextStyle brandName = TextStyle(
    fontFamily: PrismFonts.fraunces,
    fontWeight: FontWeight.bold,
    fontSize: 14,
    color: PrismColors.onPrimary,
    fontVariations: <FontVariation>[FontVariation('WONK', 1)],
  );
}

/// Icon data constants so individual widgets don't scatter icon literals.
///
/// Centralising icon choices makes it easy to swap an icon app-wide or audit
/// which icons the app uses.
abstract final class PrismIcons {
  /// Trailing chevron indicating a dropdown / expandable section.
  static const IconData dropdownCaret = Icons.expand_more_rounded;
}

/// Fixed-size dimensions for app-bar chrome.
///
/// Heights and touch targets follow Material 3 guidance. Adjust these values
/// to tune the entire app-bar in one place.
abstract final class PrismAppBarSizes {
  /// Total height of the Prism custom app-bar (excluding status bar inset).
  static const double height = 56;
}

/// Wallpaper grid columns for a screen [width]: about one per 180 pt, so a phone gets 3 in portrait
/// and 5 in landscape, and a tablet gets more instead of huge, blurry tiles.
int wallpaperGridColumns(double width) => (width / 180).round().clamp(3, 8);

/// Layout constants for the personalized feed carousel and wallpaper grid.
abstract final class PrismFeedLayout {
  /// Number of wallpaper previews shown inside the carousel.
  static const int carouselPreviewCount = 4;

  /// Grid tile aspect ratio (width : height).
  static const double gridTileAspectRatio = 0.5;

  /// How many logical pixels from the scroll end to trigger next-page fetch.
  static const double prefetchThreshold = 400;

  /// Minimal spacer appended when the feed still has more pages to load.
  static const double endOfPageSpacerHeight = 22;
}

/// Visual parameters for the `PersonalizedFeedEditorialNote` pattern.
///
/// Reuse these constants whenever you build a typographic call-out that follows
/// the same accent-bar + text column layout anywhere in the app.
/// Opacity values for overlay layers applied on top of imagery.
/// Layout and sizing tokens for modal bottom sheets.
///
/// Keeping these in one place ensures all sheets share the same visual
/// language — drag handles, section labels, action bars, and spacing all
/// derive from here.
abstract final class PrismBottomSheet {
  static const double dragHandleWidth = 32;
  static const double dragHandleHeight = 4;

  /// Fully-rounded pill radius for the drag handle.
  static const double dragHandleRadius = 99;

  /// Space between the sheet top edge and the drag handle.
  static const double topGap = 12;

  static const double chipSpacing = 8;
  static const double chipRunSpacing = 8;

  /// Share of the screen height a tall sheet (e.g. "Tune your feed") takes.
  static const double maxHeightFactor = 0.9;

  static const int interestGridColumns = 3;
  static const double interestTileSpacing = 8;
  static const double interestTileAspectRatio = 0.9;
  static const double interestTileLabelInset = 8;
  static const double interestTileSelectedBorderWidth = 2;

  /// Selected tiles sink slightly, like a pressed card.
  static const double interestTileSelectedScale = 0.96;

  /// Strongest alpha of the [ColorScheme.scrim] gradient under the tile name.
  static const double interestTileScrimAlpha = 0.65;

  static const double interestCheckBadgeSize = 22;
  static const double interestCheckIconSize = 14;

  static const int learnedTermCount = 6;
  static const EdgeInsets learnedPillPadding = EdgeInsets.fromLTRB(14, 8, 14, 10);

  /// Fixed track width so strengths compare across pills.
  static const double learnedBarWidth = 48;
  static const double learnedBarHeight = 3;
  static const double learnedBarTrackAlpha = 0.18;
}

/// Dimensions and opacities shared by all text-input fields across the app.
/// Dimensions and spacing for the edit-profile screen.
