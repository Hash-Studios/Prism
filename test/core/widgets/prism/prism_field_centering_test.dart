import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/user_search/views/widgets/prism_search_field.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  theme: prismLightThemes.first.theme,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Align(alignment: Alignment.topCenter, child: child),
    ),
  ),
);

void main() {
  for (final String text in <String>['', 'Aurora']) {
    testWidgets('the search pill centres ${text.isEmpty ? 'the hint' : 'the text'} between its edges', (tester) async {
      final TextEditingController controller = TextEditingController(text: text);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(PrismSearchField(controller: controller, hint: 'Search creators')));

      final Rect pill = tester.getRect(find.byType(PrismSearchField));
      final Rect input = tester.getRect(find.byType(EditableText));
      expect(input.center.dy, closeTo(pill.center.dy, 0.5));
      // The text starts one small gap after the icon, with no extra field padding.
      final Rect icon = tester.getRect(find.byIcon(Icons.search_rounded));
      expect(input.left - icon.right, PrismSpace.xs);
    });
  }

  testWidgets('a single-line text field centres its text', (tester) async {
    await tester.pumpWidget(_host(const SizedBox(width: 300, child: PrismTextField(hint: 'Username'))));

    final Rect field = tester.getRect(find.byType(TextField));
    expect(tester.getRect(find.byType(EditableText)).center.dy, closeTo(field.center.dy, 0.5));
  });
}
