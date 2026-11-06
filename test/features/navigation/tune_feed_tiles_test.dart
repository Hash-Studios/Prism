import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/features/navigation/views/widgets/tune_feed_tiles.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(child: child),
  );

  const PersonalizedInterest space = PersonalizedInterest(name: 'Space', query: 'space', imageUrl: '', sources: []);

  testWidgets('selecting an interest tile keeps it the same size', (tester) async {
    Future<Size> paintedSize({required bool selected}) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 120,
            height: 130,
            child: InterestTile(interest: space, selected: selected, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final RenderBox clip = tester.renderObject<RenderBox>(find.byType(ClipRRect).first);
      // Size after every transform between the tile and the screen.
      final Rect painted = MatrixUtils.transformRect(clip.getTransformTo(null), Offset.zero & clip.size);
      return painted.size;
    }

    final Size unselected = await paintedSize(selected: false);
    final Size selected = await paintedSize(selected: true);
    expect(selected, unselected);
  });

  testWidgets('a learned pill shows its term without a strength bar and reads the strength aloud', (tester) async {
    await tester.pumpWidget(host(const LearnedPill(term: 'space', strength: 0.5)));

    expect(find.text('Space'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.bySemanticsLabel('Learned: Space, 50 percent'), findsOneWidget);
  });
}
