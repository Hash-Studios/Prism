import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/prism_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _lightAppBarOverlayStyle = SystemUiOverlayStyle(
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

const _darkAppBarOverlayStyle = SystemUiOverlayStyle(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

const _defaultPink = Color(0xFFE57697);

/// Text roles for Material widgets that read the theme. App code uses `PrismTextStyles`, not these.
TextTheme _textTheme(ColorScheme cs) {
  TextStyle sans(double size, FontWeight weight, {Color? color, double? height}) => TextStyle(
    fontFamily: PrismFonts.proximaNova,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color ?? cs.onSurface,
  );
  TextStyle serif(double size) => TextStyle(
    fontFamily: PrismFonts.fraunces,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: cs.onSurface,
  );
  return TextTheme(
    displayLarge: serif(40),
    displayMedium: serif(34),
    displaySmall: serif(28),
    headlineLarge: sans(28, FontWeight.w700, height: 1.1),
    headlineMedium: sans(24, FontWeight.w700),
    headlineSmall: sans(20, FontWeight.w700),
    titleLarge: sans(20, FontWeight.w700),
    titleMedium: sans(16, FontWeight.w700),
    titleSmall: sans(15, FontWeight.w600),
    bodyLarge: sans(16, FontWeight.w500),
    bodyMedium: sans(14, FontWeight.w500),
    bodySmall: sans(12, FontWeight.w500, color: cs.onSurfaceVariant),
    labelLarge: sans(15, FontWeight.w600),
    labelMedium: sans(13, FontWeight.w600),
    labelSmall: sans(11, FontWeight.w700),
  );
}

/// Builds one Prism theme from its page [background], its text [foreground] and its default [accent].
ThemeData _theme({
  required Brightness brightness,
  required Color background,
  required Color foreground,
  required Color accent,
}) {
  final bool dark = brightness == Brightness.dark;
  return ThemeData(
    // Transparent on purpose: plain `Material` wrappers must not paint over wallpapers.
    canvasColor: Colors.transparent,
    primaryColor: background,
    brightness: brightness,
    fontFamily: PrismFonts.proximaNova,
    appBarTheme: AppBarTheme(systemOverlayStyle: dark ? _darkAppBarOverlayStyle : _lightAppBarOverlayStyle),
  ).withPrismScheme(
    prismColorScheme(brightness: brightness, background: background, foreground: foreground, accent: accent),
  );
}

// A light theme's text is a dark ink that keeps the theme's tint.
ThemeData _lightTheme({required Color background, required Color accent, Color tint = const Color(0xFF2F2F2F)}) =>
    _theme(
      brightness: Brightness.light,
      background: background,
      foreground: Color.alphaBlend(Colors.black.withValues(alpha: 0.8), tint),
      accent: accent,
    );

ThemeData _darkTheme({required Color background, required Color accent, required Color foreground}) =>
    _theme(brightness: Brightness.dark, background: background, foreground: foreground, accent: accent);

ThemeData kLightTheme = _lightTheme(background: const Color(0xFFFFFFFF), accent: _defaultPink);
ThemeData kLightTheme2 = _lightTheme(
  background: const Color(0xFFF7F1E3),
  accent: const Color(0xFFC19439),
  tint: const Color(0xFF96732C),
);
ThemeData kLightTheme3 = _lightTheme(
  background: const Color(0xFFC5A79F),
  accent: const Color(0xFFA7796D),
  tint: const Color(0xFF7D564B),
);
ThemeData kLightTheme4 = _lightTheme(
  background: const Color(0xFF8399BE),
  accent: const Color(0xFF596F95),
  tint: const Color(0xFF36435A),
);

ThemeData kDarkTheme = _darkTheme(
  background: const Color(0xFF000000),
  accent: _defaultPink,
  foreground: const Color(0xFFF0F0F0),
);
ThemeData kDarkTheme2 = _darkTheme(background: Colors.black, accent: Colors.white, foreground: Colors.white);
ThemeData kDarkTheme3 = _darkTheme(
  background: const Color(0xFF202113),
  accent: const Color(0xFF767B45),
  foreground: const Color(0xFFE3E4D0),
);
ThemeData kDarkTheme4 = _darkTheme(
  background: const Color(0xFF041B29),
  accent: const Color(0xFF427DA8),
  foreground: const Color(0xFFB0CCE0),
);
ThemeData kDarkTheme5 = _darkTheme(
  background: const Color(0xFF12210E),
  accent: const Color(0xFF4C7044),
  foreground: const Color(0xFFD9E6D6),
);
ThemeData kDarkTheme6 = _darkTheme(
  background: const Color(0xFF290D02),
  accent: const Color(0xFF703826),
  foreground: const Color(0xFFDFB0A0),
);
ThemeData kDarkTheme7 = _darkTheme(
  background: const Color(0xFF142431),
  accent: const Color(0xFF2D6079),
  foreground: const Color(0xFFA9CDDF),
);
ThemeData kDarkTheme8 = _darkTheme(
  background: const Color(0xFF393D46),
  accent: const Color(0xFF686E80),
  foreground: const Color(0xFFEEEFF2),
);

/// Applies a Prism [ColorScheme] and the component defaults that follow from it. The accent picker calls this again
/// with the user's accent, so every component default tracks the accent too.
extension PrismThemeData on ThemeData {
  ThemeData withPrismScheme(ColorScheme cs) {
    final Color hairline = cs.onSurface.withValues(alpha: 0.08);
    final TextStyle body = TextStyle(
      fontFamily: PrismFonts.proximaNova,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: cs.onSurfaceVariant,
    );
    final TextStyle title = TextStyle(
      fontFamily: PrismFonts.proximaNova,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );
    const StadiumBorder pill = StadiumBorder();
    const Size buttonSize = Size(0, 48);
    const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: PrismSpace.lg);
    OutlineInputBorder fieldBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: PrismRadius.field,
      borderSide: BorderSide(color: color, width: width),
    );
    return copyWith(
      colorScheme: cs,
      textTheme: _textTheme(cs),
      scaffoldBackgroundColor: cs.surface,
      dividerColor: hairline,
      splashColor: cs.onSurface.withValues(alpha: 0.06),
      highlightColor: cs.onSurface.withValues(alpha: 0.04),
      appBarTheme: appBarTheme.copyWith(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle: title,
        iconTheme: IconThemeData(color: cs.onSurface, size: 22),
      ),
      iconTheme: IconThemeData(color: cs.onSurface, size: 22),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        refreshBackgroundColor: cs.surfaceContainerHigh,
        linearTrackColor: hairline,
        circularTrackColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.08),
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: PrismTextStyles.button,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: PrismTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: PrismTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.onSurface,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
          shape: pill,
          textStyle: PrismTextStyles.button,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: 15),
        hintStyle: body.copyWith(fontSize: 15, color: cs.onSurface.withValues(alpha: 0.45)),
        labelStyle: body.copyWith(fontSize: 15),
        helperStyle: body.copyWith(fontSize: 12),
        errorStyle: body.copyWith(fontSize: 12, color: cs.error),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        border: fieldBorder(Colors.transparent),
        enabledBorder: fieldBorder(hairline),
        disabledBorder: fieldBorder(Colors.transparent),
        focusedBorder: fieldBorder(cs.primary, 1.5),
        errorBorder: fieldBorder(cs.error),
        focusedErrorBorder: fieldBorder(cs.error, 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cs.primary,
        selectionColor: cs.primary.withValues(alpha: 0.3),
        selectionHandleColor: cs.primary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        modalBackgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: PrismRadius.sheet),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: cs.onSurface.withValues(alpha: 0.22),
        dragHandleSize: const Size(PrismBottomSheet.dragHandleWidth, PrismBottomSheet.dragHandleHeight),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.xl),
          side: BorderSide(color: hairline),
        ),
        titleTextStyle: title.copyWith(fontSize: 20),
        contentTextStyle: body,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: body.copyWith(color: cs.onInverseSurface),
        actionTextColor: cs.onInverseSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PrismRadius.md)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.md),
          side: BorderSide(color: hairline),
        ),
        textStyle: body.copyWith(fontSize: 15, color: cs.onSurface),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurface,
        textColor: cs.onSurface,
        titleTextStyle: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
        subtitleTextStyle: body.copyWith(fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.7),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? cs.primary : cs.onSurface.withValues(alpha: 0.12),
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: cs.onSurface,
        side: BorderSide(color: cs.onSurface.withValues(alpha: 0.12)),
        shape: pill,
        labelStyle: body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xs),
        showCheckmark: false,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurface.withValues(alpha: 0.55),
        indicatorColor: cs.primary,
        dividerColor: Colors.transparent,
        labelStyle: PrismTextStyles.button,
        unselectedLabelStyle: PrismTextStyles.button.copyWith(fontWeight: FontWeight.w600),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: cs.inverseSurface, borderRadius: BorderRadius.circular(PrismRadius.xs)),
        textStyle: body.copyWith(fontSize: 12, color: cs.onInverseSurface),
        waitDuration: const Duration(milliseconds: 400),
        exitDuration: PrismDurations.press,
      ),
    );
  }
}
