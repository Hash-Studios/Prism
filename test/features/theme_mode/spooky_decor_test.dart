import 'package:Prism/features/theme_mode/views/widgets/spooky_decor.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Spooky season ends on 3 November 2026', () {
    expect(isSpookySeason(DateTime(2026, 10, 31)), isTrue);
    expect(isSpookySeason(DateTime(2026, 11, 3)), isFalse);
  });

  testWidgets('Spooky decor draws on the Spooky theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme9,
        home: const Scaffold(body: Stack(children: <Widget>[SpookyWeb(), SpookySpider()])),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsNWidgets(2));
  });

  testWidgets('Spooky decor draws nothing on the Material theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme,
        home: const Scaffold(body: Stack(children: <Widget>[SpookyWeb(), SpookySpider()])),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('Spooky spider stops animating when motion is reduced', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme9,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Stack(children: <Widget>[SpookySpider()])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
