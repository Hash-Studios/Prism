import 'package:Prism/core/arsenal/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ignore: avoid_classes_with_only_static_members
abstract final class ArsenalTypography {
  // ── Hero / Display ──────────────────────────────────────────────────────────

  /// 48px BigShouldersDisplay w800 UPPERCASE — Screen hero titles
  static TextStyle get hero => GoogleFonts.bigShouldersDisplay(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    color: ArsenalColors.onBackground,
  );

  /// 40px BigShouldersDisplay w800 UPPERCASE — Major section headers
  static TextStyle get displayLarge => GoogleFonts.bigShouldersDisplay(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: ArsenalColors.onBackground,
  );

  /// 32px BigShouldersDisplay w800 — Section headers
  static TextStyle get displayMedium =>
      GoogleFonts.bigShouldersDisplay(fontSize: 32, fontWeight: FontWeight.w800, color: ArsenalColors.onBackground);

  // ── Subheadings ─────────────────────────────────────────────────────────────

  /// 24px Rajdhani w600 — Subheadings
  static TextStyle get subheadingLarge =>
      GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.w600, color: ArsenalColors.onBackground);

  /// 18px Rajdhani w600 — Card titles
  static TextStyle get subheadingMedium =>
      GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w600, color: ArsenalColors.onBackground);

  // ── Body ────────────────────────────────────────────────────────────────────

  /// 16px Rajdhani w500 — Body copy
  static TextStyle get body =>
      GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.w500, color: ArsenalColors.onBackground);

  /// 14px Rajdhani w500 — Secondary body
  static TextStyle get bodySmall =>
      GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.w500, color: ArsenalColors.onBackground);

  // ── Buttons / Labels ────────────────────────────────────────────────────────

  /// 14px Rajdhani w700 UPPERCASE — Button text
  static TextStyle get buttonLabel => GoogleFonts.rajdhani(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: ArsenalColors.onBackground,
  );

  /// 13px Rajdhani w700 — UI emphasis labels
  static TextStyle get labelEmphasis =>
      GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.w700, color: ArsenalColors.onBackground);

  /// 12px Rajdhani w600 — Standard UI labels
  static TextStyle get label =>
      GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w600, color: ArsenalColors.onBackground);

  // ── Mono ─────────────────────────────────────────────────────────────────────

  /// 13px JetBrainsMono w700 UPPERCASE — Step counters, status, codes
  static TextStyle get monoHighlight => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    color: ArsenalColors.onBackground,
  );

  /// 12px JetBrainsMono w400 — Timestamps, secondary technical text
  static TextStyle get mono =>
      GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w400, color: ArsenalColors.onBackground);
}
