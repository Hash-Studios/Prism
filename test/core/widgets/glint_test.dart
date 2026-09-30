import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/glint/glint_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );

  testWidgets('every mood paints at the start, at its still pose and part way through', (WidgetTester tester) async {
    for (final GlintMood mood in GlintMood.values) {
      final GlintMoodSpec spec = glintSpecOf(mood);
      for (final double seconds in <double>[0, spec.stillAt, .37 * spec.period]) {
        await tester.pumpWidget(host(GlintPose(mood: mood, seconds: seconds)));
      }
      await tester.pumpWidget(host(GlintPose(mood: mood, seconds: 0, still: true)));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Glint loops while shown', (WidgetTester tester) async {
    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy)));
    // Bounded pumps: Glint never settles.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('under reduce-motion Glint holds a still pose and schedules no frame', (WidgetTester tester) async {
    await tester.pumpWidget(host(const Glint(mood: GlintMood.sleepy), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isFalse);
    final GlintPose pose = tester.widget(find.byType(GlintPose));
    expect(pose.still, isTrue);
    expect(pose.mood, GlintMood.sleepy);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('a new mood starts its loop from the top', (WidgetTester tester) async {
    double seconds() => tester.widget<GlintPose>(find.byType(GlintPose)).seconds;

    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy)));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(seconds(), greaterThan(1));

    await tester.pumpWidget(host(const Glint(mood: GlintMood.sad)));
    expect(seconds(), lessThan(.1));
  });

  testWidgets('Glint is a picture: screen readers skip it', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        Semantics(
          container: true,
          label: 'box',
          child: const Glint(mood: GlintMood.love),
        ),
        reduceMotion: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('box')),
      matchesSemantics(label: 'box', children: const <Matcher>[]),
    );
    semantics.dispose();
  });

  test('the keys of every mood start at 0, end at 1 and never go back', () {
    for (final GlintMood mood in GlintMood.values) {
      final GlintMoodSpec spec = glintSpecOf(mood);
      expect(spec.stillAt, lessThan(spec.period), reason: mood.name);
      for (final MapEntry<String, List<GlintKey>> part in spec.parts.entries) {
        final List<double> times = [for (final GlintKey k in part.value) k.t];
        expect(times.first, 0, reason: '${mood.name} ${part.key}');
        expect(times.last, 1, reason: '${mood.name} ${part.key}');
        for (int i = 1; i < times.length; i++) {
          expect(times[i], greaterThanOrEqualTo(times[i - 1]), reason: '${mood.name} ${part.key}');
        }
      }
    }
  });

  test('the crystal stays inside the 160 x 160 box in every mood', () {
    for (final GlintMood mood in GlintMood.values) {
      for (int i = 0; i < 24; i++) {
        for (final Offset corner in glintCrystalCornersAt(mood, i / 24)) {
          expect(corner.dx, inInclusiveRange(0, 160), reason: '${mood.name} at ${i / 24}');
          expect(corner.dy, inInclusiveRange(0, 160), reason: '${mood.name} at ${i / 24}');
        }
      }
    }
  });
}
