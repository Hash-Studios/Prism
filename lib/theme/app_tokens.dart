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

  /// White for content over photography and scrims. Do not use it on theme surfaces such as `primaryColor`,
  /// which is white in Frost White. Use `onColor` from `contrast.dart` there.
  static const Color onPrimary = Colors.white;

  /// Destructive red for light surfaces. Also the fill for destructive buttons that carry white text.
  static const Color destructiveLight = Color(0xFFD93036);

  /// Destructive red for dark surfaces.
  static const Color destructiveDark = Color(0xFFFF6369);

  /// Text and icon colour for destructive actions such as Delete Account. It does not follow the user accent.
  static Color destructive(Brightness brightness) => brightness == Brightness.dark ? destructiveDark : destructiveLight;
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

/// Metrics of the app-wide chip theme built by `withPrismChipTheme` in `theme.dart`.
abstract final class PrismChipMetrics {
  static const double fontSize = 14;

  /// Line height factor. It fixes the label at 18 px, so the chip is 36 px high with [padding].
  static const double labelHeight = 1.3;

  static const double iconSize = 16;

  /// Around the label and the icon. With [labelPadding] a chip has 14 px at each end. A chip that sets its own
  /// padding keeps this label padding, so its text never touches the rounded end.
  static const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 6, vertical: 9);
  static const EdgeInsets labelPadding = EdgeInsets.symmetric(horizontal: 8);

  /// Alpha of the foreground colour for the fill of an unselected chip.
  static const double restFillAlpha = 0.08;

  /// Alpha of the foreground colour for the fill of a disabled chip.
  static const double disabledFillAlpha = 0.08;

  /// Alpha of the label of a disabled chip.
  static const double disabledLabelAlpha = 0.5;

  /// The avatar box is 24 px wide for a 16 px icon, so the icon keeps clear of the rounded end.
  static const BoxConstraints avatarConstraints = BoxConstraints.tightFor(width: 24, height: 16);

  /// Contrast an unselected label must reach against its fill. A theme foreground that is weaker is darkened
  /// (or lightened) until it does.
  static const double minLabelContrast = 4.5;
}

/// Secondary text in the theme foreground colour that sits on the page, such as an unselected tab or a count line.
abstract final class PrismInk {
  /// Alpha of secondary text. A theme whose ink falls under [PrismChipMetrics.minLabelContrast] at this alpha keeps full ink.
  static const double softAlpha = 0.8;
}

/// Icon data constants so individual widgets don't scatter icon literals.
///
/// Centralising icon choices makes it easy to swap an icon app-wide or audit
/// which icons the app uses.
abstract final class PrismIcons {
  /// Trailing chevron indicating a dropdown / expandable section.
  static const IconData dropdownCaret = Icons.expand_more_rounded;
}

/// Wallpaper grid columns for a screen [width]: about one per 180 pt, so a phone gets 3 in portrait
/// and 5 in landscape, and a tablet gets more instead of huge, blurry tiles.
int wallpaperGridColumns(double width) => (width / 180).round().clamp(3, 8);

/// Columns for a grid of large wallpaper tiles: 2 on any phone (narrower than 600), then one per 200 pt up to 6.
int largeTileGridColumns(double width) => (width / 200).floor().clamp(2, 6);

/// Width caps for tablets. Each cap is wider than any phone, so a phone keeps the full screen width.
abstract final class PrismLayout {
  /// Most a page of text, lists or forms grows to. The same as the bottom sheet's width cap.
  static const double readableWidth = 640;

  /// Most a floating panel or bar over full-screen art grows to.
  static const double panelWidth = 560;

  /// Shortest side, in logical pixels, from which a screen is a tablet.
  static const double tabletShortestSide = 600;
}

/// Layout constants for the personalized feed carousel and wallpaper grid.
abstract final class PrismFeedLayout {
  /// Number of wallpaper previews shown inside the carousel.
  static const int carouselPreviewCount = 4;

  /// Grid tile aspect ratio (width : height).
  static const double gridTileAspectRatio = 0.5;

  /// Minimal spacer appended when the feed still has more pages to load.
  static const double endOfPageSpacerHeight = 22;

  /// Gap between tiles of the home grid, on both axes. The side margin is the same, so the gutters are even.
  static const double gridSpacing = 4.0;

  static const EdgeInsets gridPadding = EdgeInsets.symmetric(horizontal: gridSpacing);
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
  static const double dragHandleWidth = 36;
  static const double dragHandleHeight = 4;

  /// Fully-rounded pill radius for the drag handle.
  static const double dragHandleRadius = 99;

  /// Gap between a floating sheet and the screen edges. It goes to 0 as the sheet is dragged to full height.
  static const double inset = 16;

  /// Gap between the status bar and the top of a full-height sheet.
  static const double topInset = 6;

  /// Radius of the sheet's top corners. The bottom corners follow the screen's own corner radius.
  static const double topRadius = 32;

  /// Height of the header row that holds the close button, the title and the trailing action.
  static const double headerRowHeight = 44;

  /// Width kept for the header's leading and trailing slots, so the title stays centred.
  static const double headerSlotWidth = 44;

  static const double closeButtonSize = 40;

  static const EdgeInsets headerPadding = EdgeInsets.symmetric(horizontal: PrismSpace.xl, vertical: PrismSpace.xs);
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(PrismSpace.xl, 0, PrismSpace.xl, PrismSpace.xl);
  static const EdgeInsets actionsPadding = EdgeInsets.fromLTRB(
    PrismSpace.xl,
    PrismSpace.sm,
    PrismSpace.xl,
    PrismSpace.sm,
  );

  /// Cast under the floating sheet. Heavier than a card, so the sheet reads as a separate object.
  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(color: Color(0x29000000), offset: Offset(0, 2), blurRadius: 6),
    BoxShadow(color: Color(0x33000000), offset: Offset(0, 14), blurRadius: 36),
  ];

  /// Dims the screen behind a sheet.
  static const Color barrier = Color(0x52000000);

  static const double chipSpacing = 8;
  static const double chipRunSpacing = 8;

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
