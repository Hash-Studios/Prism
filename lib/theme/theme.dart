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

const _lightMain = Color(0xFFFFFFFF);
const _lightSecond = Color(0xFFEDEDED);
const _lightAccent = Color(0xFF2F2F2F);
const _darkMain = Color(0xFF000000);
const _darkSecond = Color(0xFF2F2F2F);
const _darkAccent = Color(0xFFF0F0F0);
const _defaultPink = Color(0xFFE57697);

ThemeData _lightTheme({
  required Color primary,
  required Color hint,
  required Color accent,
  Color secondary = _lightAccent,
}) {
  return ThemeData(
    canvasColor: Colors.transparent,
    primaryColor: primary,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(systemOverlayStyle: _lightAppBarOverlayStyle),
    focusColor: _lightMain,
    hintColor: hint,
    textTheme: TextTheme(
      labelLarge: const TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _lightMain,
      ),
      headlineSmall: const TextStyle(fontSize: 16.0, color: _lightMain, fontFamily: PrismFonts.proximaNova),
      headlineMedium: const TextStyle(
        fontSize: 16,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: _lightAccent,
      ),
      displaySmall: const TextStyle(
        fontSize: 20,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      displayMedium: const TextStyle(
        fontSize: 24,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      displayLarge: const TextStyle(
        fontFamily: PrismFonts.proximaNova,
        color: _lightAccent,
        fontSize: 50,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: _lightSecond,
        fontFamily: PrismFonts.roboto,
      ),
      titleLarge: TextStyle(
        fontSize: 13.0,
        color: _lightMain.withValues(alpha: .85),
        fontFamily: PrismFonts.proximaNova,
      ),
      bodyMedium: TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _lightMain.withValues(alpha: .75),
      ),
      bodyLarge: const TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: _lightMain,
      ),
      bodySmall: const TextStyle(
        fontFamily: PrismFonts.roboto,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: _lightAccent,
      ),
    ),
  ).withPrismScheme(
    prismColorScheme(
      brightness: Brightness.light,
      background: primary,
      // A dark ink that keeps the theme's tint.
      foreground: Color.alphaBlend(Colors.black.withValues(alpha: 0.8), secondary),
      accent: accent,
    ),
  );
}

ThemeData _darkTheme({
  required Color primary,
  required Color hint,
  required Color accent,
  required Color secondary,
  Color text = _darkAccent,
  Color titleMedium = _darkSecond,
}) {
  return ThemeData(
    canvasColor: Colors.transparent,
    primaryColor: primary,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
    focusColor: _darkMain,
    hintColor: hint,
    textTheme: TextTheme(
      labelLarge: const TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _darkMain,
      ),
      headlineSmall: TextStyle(fontSize: 16.0, color: text, fontFamily: PrismFonts.proximaNova),
      headlineMedium: TextStyle(
        fontSize: 16,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: text,
      ),
      displaySmall: const TextStyle(
        fontSize: 20,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      displayMedium: const TextStyle(
        fontSize: 24,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      displayLarge: TextStyle(
        fontFamily: PrismFonts.proximaNova,
        color: text,
        fontSize: 50,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: titleMedium,
        fontFamily: PrismFonts.roboto,
      ),
      titleLarge: TextStyle(fontSize: 14.0, color: text.withValues(alpha: .85), fontFamily: PrismFonts.proximaNova),
      bodyMedium: TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: text.withValues(alpha: .85),
      ),
      bodyLarge: TextStyle(fontFamily: PrismFonts.proximaNova, fontSize: 22, fontWeight: FontWeight.w500, color: text),
      bodySmall: TextStyle(fontFamily: PrismFonts.roboto, fontSize: 16, fontWeight: FontWeight.w400, color: text),
    ),
  ).withPrismScheme(
    prismColorScheme(brightness: Brightness.dark, background: primary, foreground: secondary, accent: accent),
  );
}

ThemeData kLightTheme = _lightTheme(primary: _lightMain, hint: _lightSecond, accent: _defaultPink);

ThemeData kLightTheme2 = _lightTheme(
  primary: const Color(0xFFF7F1E3),
  hint: const Color(0xFFF1E6D0),
  accent: const Color(0xFFC19439),
  secondary: const Color(0xFF96732C),
);

ThemeData kLightTheme3 = _lightTheme(
  primary: const Color(0xFFC5A79F),
  hint: const Color(0xFFBE9C93),
  accent: const Color(0xFFA7796D),
  secondary: const Color(0xFF7D564B),
);

ThemeData kLightTheme4 = _lightTheme(
  primary: const Color(0xFF8399BE),
  hint: const Color(0xFF788CAF),
  accent: const Color(0xFF596F95),
  secondary: const Color(0xFF36435A),
);

ThemeData kDarkTheme = _darkTheme(primary: _darkMain, hint: _darkSecond, accent: _defaultPink, secondary: _darkAccent);

ThemeData kDarkTheme2 = _darkTheme(
  primary: Colors.black,
  hint: Colors.black,
  accent: Colors.white,
  secondary: Colors.white,
  text: Colors.white,
  titleMedium: Colors.black,
);

ThemeData kDarkTheme3 = _darkTheme(
  primary: const Color(0xFF202113),
  hint: const Color(0xFF35371F),
  accent: const Color(0xFF767B45),
  secondary: const Color(0xFFE3E4D0),
);

ThemeData kDarkTheme4 = _darkTheme(
  primary: const Color(0xFF041B29),
  hint: const Color(0xFF152836),
  accent: const Color(0xFF427DA8),
  secondary: const Color(0xFFB0CCE0),
);

ThemeData kDarkTheme5 = _darkTheme(
  primary: const Color(0xFF12210E),
  hint: const Color(0xFF1D2B1A),
  accent: const Color(0xFF4C7044),
  secondary: const Color(0xFFD9E6D6),
);

ThemeData kDarkTheme6 = _darkTheme(
  primary: const Color(0xFF290D02),
  hint: const Color(0xFF361B12),
  accent: const Color(0xFF703826),
  secondary: const Color(0xFFDFB0A0),
);

ThemeData kDarkTheme7 = _darkTheme(
  primary: const Color(0xFF142431),
  hint: const Color(0xFF193543),
  accent: const Color(0xFF2D6079),
  secondary: const Color(0xFFA9CDDF),
);

ThemeData kDarkTheme8 = _darkTheme(
  primary: const Color(0xFF393D46),
  hint: const Color(0xFF33363F),
  accent: const Color(0xFF686E80),
  secondary: const Color(0xFFEEEFF2),
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
