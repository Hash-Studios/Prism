import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

/// Hard-coded semantic color tokens for Prism UI chrome.
///
/// Prefer [Theme.of(context).colorScheme] for surface/content colors that
/// change with the active theme. Use [PrismColors] only for values that must
/// remain constant across all themes — e.g. brand accents and overlay helpers.
abstract final class PrismColors {
  /// Brand pink — notification badge fill and primary accent in the default
  /// theme's color scheme.
  static const Color brandPink = Color(0xFFFF69A9);

  /// Semi-transparent brand pink used as a glow shadow on the notification dot.
  static const Color notificationBadgeShadow = Color(0x80E57697);

  /// Foreground color on primary / app-bar surfaces.
  /// Always white so that content stays legible regardless of the active theme.
  static const Color onPrimary = Colors.white;
}

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

/// Font family name constants.
///
/// Keep font strings in one place so renaming a family only requires one edit.
abstract final class PrismFonts {
  static const String proximaNova = 'Proxima Nova';
  static const String fraunces = 'Fraunces';
  static const String roboto = 'Roboto';
}

// ---------------------------------------------------------------------------
// Text styles
// ---------------------------------------------------------------------------

/// Pre-built text styles for recurring chrome and editorial patterns.
///
/// Where a style must adapt to the active theme use the static helper methods
/// (which accept a [BuildContext]). Purely structural styles that do not vary
/// by theme are exposed as `const` values.
abstract final class PrismTextStyles {
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

  /// Large bold headline overlaid on full-bleed carousel banners.
  ///
  /// Inherits the theme's [displayMedium] as a base so that font family and
  /// letter-spacing stay consistent, then overrides size, weight, and color
  /// for legibility on arbitrary photography.
  static TextStyle carouselBannerHeadline(BuildContext context) {
    return (Theme.of(context).textTheme.displayMedium ?? const TextStyle()).copyWith(
      fontSize: PrismFeedLayout.carouselBannerFontSize,
      color: PrismColors.onPrimary,
      fontWeight: FontWeight.bold,
    );
  }

  /// Primary label in editorial note / empty-state cards.
  static TextStyle editorialTitle(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
  }

  /// Supporting body copy in editorial note / empty-state cards.
  static TextStyle editorialDetail(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
  }

  /// AppBar title for full-screen edit panels (e.g. "Edit Profile").
  ///
  /// Fraunces at 17 sp keeps the branded feel while fitting comfortably in an
  /// AppBar without overpowering the content below. Use [sheetTitle] (20 sp)
  /// for modal bottom-sheet headers where more vertical space is available.
  static TextStyle panelTitle(BuildContext context) {
    return TextStyle(
      fontFamily: PrismFonts.fraunces,
      fontWeight: FontWeight.bold,
      fontSize: 17,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Primary headline for bottom-sheet and panel headers (e.g. "Your feed").
  ///
  /// Uses the Fraunces brand font — the same family as the app-bar wordmark —
  /// so every sheet feels like a first-class Prism surface. No WONK variation
  /// at this display size; the natural Fraunces character is expressive enough.
  static TextStyle sheetTitle(BuildContext context) {
    return TextStyle(
      fontFamily: PrismFonts.fraunces,
      fontWeight: FontWeight.bold,
      fontSize: 20,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Muted section label used inside bottom sheets and settings panels.
  ///
  /// Uses [bodyMedium] (14 sp, Proxima Nova w500) as the base so it sits
  /// clearly below the [sheetTitle] in the hierarchy — avoiding the inverted
  /// weight that occurs when [labelLarge] (16 sp w800) is used here instead.
  /// A subtle letter-spacing gives it the editorial label feel without weight.
  static TextStyle sheetSectionLabel(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
    );
  }

  /// Standard input text inside form fields (name, username, bio, link).
  static TextStyle fieldInput(BuildContext context) {
    return TextStyle(
      fontFamily: PrismFonts.proximaNova,
      fontSize: PrismFormField.inputFontSize,
      color: Theme.of(context).colorScheme.secondary,
    );
  }

  /// Slightly smaller input text for compact field contexts (e.g. link row).
  static TextStyle fieldInputSmall(BuildContext context) {
    return TextStyle(
      fontFamily: PrismFonts.proximaNova,
      fontSize: PrismFormField.inputFontSizeSmall,
      color: Theme.of(context).colorScheme.secondary,
    );
  }

  /// Small muted caption below form fields (e.g. username constraints hint).
  static TextStyle fieldCaption(BuildContext context) {
    return TextStyle(
      fontFamily: PrismFonts.proximaNova,
      fontSize: 12,
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
      height: 1.5,
    );
  }

  /// Overlay label on top of photography (e.g. "Edit cover" hint).
  static const TextStyle photoOverlayLabel = TextStyle(
    fontFamily: PrismFonts.proximaNova,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: PrismColors.onPrimary,
  );
}

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

/// Icon data constants so individual widgets don't scatter icon literals.
///
/// Centralising icon choices makes it easy to swap an icon app-wide or audit
/// which icons the app uses.
abstract final class PrismIcons {
  /// Filled bell — primary notification icon used in the app-bar and surfaces
  /// that surface notification state.
  static const IconData notificationBell = JamIcons.bell_f;

  /// Trailing chevron indicating a dropdown / expandable section.
  static const IconData dropdownCaret = Icons.expand_more_rounded;
}

// ---------------------------------------------------------------------------
// App-bar sizes
// ---------------------------------------------------------------------------

/// Fixed-size dimensions for app-bar chrome.
///
/// Heights and touch targets follow Material 3 guidance. Adjust these values
/// to tune the entire app-bar in one place.
abstract final class PrismAppBarSizes {
  /// Total height of the Prism custom app-bar (excluding status bar inset).
  static const double height = 56;

  /// Symmetric horizontal padding inside the app-bar row.
  static const double horizontalPadding = 18;

  /// Touch-target size for icon buttons (44 × 44 px meets a11y minimums).
  static const double iconButtonTouchTarget = 44;

  /// Visual icon size inside app-bar buttons.
  static const double iconSize = 16;

  // -- Profile avatar --------------------------------------------------------

  static const double profileAvatarSize = 40;
  static const double profileAvatarInnerPadding = 8;

  // -- Notification badge dot ------------------------------------------------

  static const double notificationBadgeSize = 6;
  static const double notificationBadgeBlurRadius = 4;
  static const double notificationBadgeSpreadRadius = 1;
}

// ---------------------------------------------------------------------------
// Feed layout
// ---------------------------------------------------------------------------

/// Layout constants for the personalized feed carousel and wallpaper grid.
abstract final class PrismFeedLayout {
  // -- Carousel --------------------------------------------------------------

  /// Carousel height = screen width × this ratio (2 : 3 portrait aspect).
  static const double carouselHeightRatio = 2 / 3;

  /// Number of wallpaper previews shown inside the carousel.
  static const int carouselPreviewCount = 4;

  /// Font size for the carousel banner overlay headline.
  static const double carouselBannerFontSize = 20;

  // -- Grid ------------------------------------------------------------------

  /// Grid tile aspect ratio (width : height).
  static const double gridTileAspectRatio = 0.5;

  /// Number of grid columns in portrait orientation.
  static const int gridColumnCountPortrait = 3;

  /// Number of grid columns in landscape orientation.
  static const int gridColumnCountLandscape = 5;

  /// How many logical pixels from the scroll end to trigger next-page fetch.
  static const double prefetchThreshold = 400;

  /// Stroke width for the inline "fetching more" progress indicator.
  static const double loadingIndicatorStrokeWidth = 2.4;

  // -- Padding presets -------------------------------------------------------

  /// Padding for the error state (generous top space pushes the note to
  /// roughly the vertical centre of the visible area).
  static const EdgeInsets errorStatePadding = EdgeInsets.fromLTRB(24, 120, 24, 32);

  /// Padding for empty / end-of-feed messages.
  static const EdgeInsets contentStatePadding = EdgeInsets.fromLTRB(24, 12, 24, 28);

  /// Padding wrapping the inline "fetching more" spinner.
  static const EdgeInsets loadingStatePadding = EdgeInsets.fromLTRB(0, 8, 0, 26);

  /// Minimal spacer appended when the feed still has more pages to load.
  static const double endOfPageSpacerHeight = 22;
}

// ---------------------------------------------------------------------------
// Editorial note / empty-state cards
// ---------------------------------------------------------------------------

/// Visual parameters for the `PersonalizedFeedEditorialNote` pattern.
///
/// Reuse these constants whenever you build a typographic call-out that follows
/// the same accent-bar + text column layout anywhere in the app.
abstract final class PrismEditorialNote {
  // -- Accent bar ------------------------------------------------------------

  static const double accentBarWidth = 3;
  static const double accentBarHeight = 52;
  static const double accentBarBorderRadius = 2;

  /// Horizontal gap between the accent bar and the text column.
  static const double accentBarTextGap = 16;

  // -- Text ------------------------------------------------------------------

  /// Vertical spacing between the title and the detail paragraph.
  static const double titleDetailSpacing = 8;

  // -- Container -------------------------------------------------------------

  /// Maximum width of the note container — keeps line length readable on
  /// wider screens and tablets.
  static const double maxWidth = 360;

  /// Symmetric horizontal padding inside the note container.
  static const double horizontalPadding = 8;
}

// ---------------------------------------------------------------------------
// Overlay / scrim
// ---------------------------------------------------------------------------

/// Opacity values for overlay layers applied on top of imagery.
abstract final class PrismOverlay {
  /// Scrim alpha for the banner text overlay on top of carousel photography.
  static const double carouselBannerScrimAlpha = 0.45;
}

// ---------------------------------------------------------------------------
// Bottom sheet chrome
// ---------------------------------------------------------------------------

/// Layout and sizing tokens for modal bottom sheets.
///
/// Keeping these in one place ensures all sheets share the same visual
/// language — drag handles, section labels, action bars, and spacing all
/// derive from here.
abstract final class PrismBottomSheet {
  // -- Drag handle -----------------------------------------------------------

  static const double dragHandleWidth = 32;
  static const double dragHandleHeight = 4;

  /// Fully-rounded pill radius for the drag handle.
  static const double dragHandleRadius = 99;

  // -- Vertical rhythm -------------------------------------------------------

  /// Space between the sheet top edge and the drag handle.
  static const double topGap = 12;

  /// Space between the drag handle and the first content section.
  static const double headerGap = 16;

  /// Vertical gap inserted before each new section heading.
  static const double sectionTopGap = 16;

  /// Space between a section label and the content below it.
  static const double sectionLabelBottomGap = 4;

  // -- Horizontal padding ----------------------------------------------------

  /// Consistent horizontal inset used for headers, section labels, and
  /// the action bar — keeps the vertical rhythm of the whole sheet aligned.
  static const double horizontalPadding = 20;

  // -- Interest chips --------------------------------------------------------

  static const double chipSpacing = 8;
  static const double chipRunSpacing = 8;

  /// Uniform padding inside the scrollable chip area.
  static const EdgeInsets chipAreaPadding = EdgeInsets.all(16);

  // -- Action bar ------------------------------------------------------------

  /// Vertical padding inside the action bar row.
  static const double actionsVerticalPadding = 12;

  // -- Saving spinner --------------------------------------------------------

  /// Size of the inline saving indicator inside the "Save" button.
  static const double savingIndicatorSize = 16;

  /// Stroke width for the inline saving spinner.
  static const double savingIndicatorStrokeWidth = 2;

  // -- Keyboard avoidance ----------------------------------------------------

  /// Extra bottom clearance added on top of the keyboard inset.
  static const double keyboardSafetyBuffer = 8;
}

// ---------------------------------------------------------------------------
// Form fields
// ---------------------------------------------------------------------------

/// Dimensions and opacities shared by all text-input fields across the app.
abstract final class PrismFormField {
  static const double borderRadius = 8;
  static const double borderWidth = 1.5;

  /// Opacity of the resting (unfocused) border.
  static const double restingBorderOpacity = 0.22;

  /// Opacity of field labels in their resting state.
  static const double labelOpacity = 0.65;

  /// Opacity of hint / placeholder text.
  static const double hintOpacity = 0.45;

  /// Opacity of trailing/prefix icons inside fields.
  static const double iconOpacity = 0.4;

  static const EdgeInsets contentPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 18);

  static const double inputFontSize = 15;
  static const double inputFontSizeSmall = 14;
  static const double labelFontSize = 14;
  static const double hintFontSize = 13;

  /// Width/height of the username-availability icon well.
  static const double availabilityIndicatorSize = 48;

  /// Size of the username-check icon (tick / cross).
  static const double availabilityIconSize = 20;

  /// Size of the checking spinner.
  static const double availabilitySpinnerSize = 18;
}

// ---------------------------------------------------------------------------
// Profile editing
// ---------------------------------------------------------------------------

/// Dimensions and spacing for the edit-profile screen.
abstract final class PrismProfile {
  // -- Avatar ----------------------------------------------------------------

  static const double avatarSize = 88;

  /// How far the avatar overlaps below the cover image.
  static const double avatarOverlap = 44;
  static const double avatarBorderWidth = 3;

  // -- Camera chip (avatar badge) --------------------------------------------

  static const double cameraChipSize = 26;
  static const double cameraChipBorderWidth = 2;
  static const double cameraChipIconSize = 13;

  // -- Cover area ------------------------------------------------------------

  static const double coverScrimHeight = 52;
  static const double coverEditIconSize = 15;
  static const double coverEditIconGap = 6;

  // -- Remove chip (top-right corner of cover) -------------------------------

  static const double removeChipSize = 32;
  static const double removeChipIconSize = 15;
  static const double removeChipScrimAlpha = 0.45;
  static const double removeChipPositionOffset = 10;

  // -- Form field vertical rhythm --------------------------------------------

  static const double fieldGap = 12;
  static const double preSaveGap = 28;
  static const double postSaveGap = 16;
  static const double bottomPadding = 40;

  // -- Link row --------------------------------------------------------------

  static const double linkSelectorHeight = 56;
  static const double linkSelectorHorizontalPadding = 12;
  static const double linkSelectorGap = 10;
  static const double linkSelectorIconSize = 20;
  static const double linkSelectorCaretSize = 12;
  static const double linkDropdownIconSize = 18;
  static const double linkDropdownTextGap = 12;
  static const double linkDropdownFontSize = 14;

  // -- Save button -----------------------------------------------------------

  static const double saveButtonHeight = 56;
  static const double savingIndicatorSize = 22;
  static const double savingIndicatorStrokeWidth = 2.5;

  // -- Dialog ----------------------------------------------------------------

  static const double dialogBorderRadius = 16;
  static const double dialogButtonRadius = 8;
  static const double dialogTitleFontSize = 17;
  static const double dialogBodyFontSize = 14;
  static const double dialogBodyOpacity = 0.65;
}
