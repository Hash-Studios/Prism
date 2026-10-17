import 'package:Prism/core/widgets/cosmetics/glow_text.dart';
import 'package:Prism/core/widgets/cosmetics/profile_frame.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  const Key childKey = ValueKey<String>('child');

  Widget frame(String? id, {bool premium = false}) => ProfileFrame(
    frameId: id,
    premium: premium,
    size: 80,
    child: const SizedBox.expand(key: childKey),
  );

  group('ProfileFrame', () {
    testWidgets('draws no ring without an id', (tester) async {
      await tester.pumpWidget(_host(frame(null)));

      expect(find.byKey(ProfileFrame.ringKey), findsNothing);
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 80));
    });

    testWidgets('draws no ring for an unknown id or an id of another kind', (tester) async {
      await tester.pumpWidget(_host(frame('frame_missing')));
      expect(find.byKey(ProfileFrame.ringKey), findsNothing);

      await tester.pumpWidget(_host(frame('glow_ember')));
      expect(find.byKey(ProfileFrame.ringKey), findsNothing);
    });

    testWidgets('draws a ring and keeps the footprint for a known frame', (tester) async {
      await tester.pumpWidget(_host(frame('frame_aurora')));

      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
      expect(tester.getSize(find.byType(ProfileFrame)), const Size(80, 80));
      expect(tester.getSize(find.byKey(childKey)).width, lessThan(80));
    });

    testWidgets('draws a solid ring for a one colour frame', (tester) async {
      await tester.pumpWidget(_host(frame('frame_ring')));

      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
    });

    testWidgets('a Pro frame draws only while the profile is premium', (tester) async {
      await tester.pumpWidget(_host(frame('frame_prism')));
      expect(find.byKey(ProfileFrame.ringKey), findsNothing);

      await tester.pumpWidget(_host(frame('frame_prism', premium: true)));
      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
    });

    test('draws mirrors what build does', () {
      expect(ProfileFrame.draws('frame_gold', premium: false), isTrue);
      expect(ProfileFrame.draws('frame_prism', premium: false), isFalse);
      expect(ProfileFrame.draws(null, premium: true), isFalse);
    });
  });

  group('PrismAvatar', () {
    testWidgets('wraps itself in the frame and keeps its size', (tester) async {
      await tester.pumpWidget(_host(const PrismAvatar(name: 'Ana', size: 52, frameId: 'frame_gold')));

      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
      expect(tester.getSize(find.byType(ProfileFrame)), const Size(52, 52));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('without a frame it looks as before', (tester) async {
      await tester.pumpWidget(_host(const PrismAvatar(name: 'Ana', size: 52)));

      expect(find.byKey(ProfileFrame.ringKey), findsNothing);
      expect(tester.getSize(find.byType(PrismAvatar)), const Size(52, 52));
    });

    testWidgets('a Pro frame needs premium', (tester) async {
      await tester.pumpWidget(_host(const PrismAvatar(name: 'Ana', frameId: 'frame_prism')));
      expect(find.byKey(ProfileFrame.ringKey), findsNothing);

      await tester.pumpWidget(_host(const PrismAvatar(name: 'Ana', frameId: 'frame_prism', premium: true)));
      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
    });
  });

  group('GlowText', () {
    testWidgets('is plain text without a glow id', (tester) async {
      await tester.pumpWidget(_host(const GlowText('Ana')));

      expect(find.text('Ana'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('is plain text for an unknown id or an id of another kind', (tester) async {
      await tester.pumpWidget(_host(const GlowText('Ana', glowId: 'glow_missing')));
      expect(find.byType(ShaderMask), findsNothing);

      await tester.pumpWidget(_host(const GlowText('Ana', glowId: 'frame_ring')));
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('fills the text with the gradient and a soft shadow for a known glow', (tester) async {
      await tester.pumpWidget(_host(const GlowText('Ana', glowId: 'glow_ocean', style: TextStyle(fontSize: 20))));

      expect(find.byType(ShaderMask), findsOneWidget);
      final Text text = tester.widget<Text>(find.text('Ana'));
      expect(text.style?.shadows, isNotEmpty);
      expect(text.style?.fontSize, 20);
    });
  });
}
