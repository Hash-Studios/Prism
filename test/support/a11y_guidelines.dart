import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One theme, text size and reading direction that a screen must work in.
class A11yVariant {
  const A11yVariant(this.brightness, this.textScale, this.direction);

  final Brightness brightness;
  final double textScale;
  final TextDirection direction;

  @override
  String toString() => '${brightness.name}, ${textScale}x text, ${direction.name}';
}

/// Light and dark, 1x and 2x text, LTR and RTL.
final List<A11yVariant> a11yVariants = <A11yVariant>[
  for (final Brightness brightness in Brightness.values)
    for (final double textScale in <double>[1, 2])
      for (final TextDirection direction in TextDirection.values) A11yVariant(brightness, textScale, direction),
];

/// Wraps [home] in the app's theme and localizations for one [variant].
Widget a11yApp(
  Widget home, {
  A11yVariant variant = const A11yVariant(Brightness.light, 1, TextDirection.ltr),
  bool reduceMotion = false,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: variant.brightness == Brightness.light ? kLightTheme : kDarkTheme,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(variant.textScale)),
    child: Directionality(textDirection: variant.direction, child: child!),
  ),
  home: home,
);

/// Pumps [build] in every [a11yVariants] entry and checks the Android and iOS tap target sizes, tap target labels,
/// text contrast, and that nothing overflows.
///
/// [settle] runs after each pump, for example to open a sheet. [contrast] is false for a surface whose text sits on
/// a wallpaper photo: the guideline reads the photo pixels, which a test fixture does not have.
Future<void> expectA11yGuidelines(
  WidgetTester tester,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? settle,
  bool contrast = true,
  List<A11yVariant>? variants,
}) async {
  final SemanticsHandle semantics = tester.ensureSemantics();
  for (final A11yVariant variant in variants ?? a11yVariants) {
    await tester.pumpWidget(a11yApp(build(), variant: variant));
    await (settle ?? (WidgetTester t) => t.pumpAndSettle())(tester);
    expect(tester.takeException(), isNull, reason: '$variant');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: '$variant');
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: '$variant');
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: '$variant');
    if (contrast) await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$variant');
    await tester.pumpWidget(const SizedBox.shrink());
  }
  semantics.dispose();
}
