import 'package:Prism/features/library/views/widgets/recently_set_row.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppliedWallpaper _item(String id, {String? fullUrl, DateTime? at}) => AppliedWallpaper(
  id: id,
  source: 'prism',
  thumbnailUrl: '/missing/$id.jpg',
  fullUrl: fullUrl ?? 'https://example.com/$id.jpg',
  target: 'home',
  appliedAt: at ?? DateTime.utc(2026),
);

void main() {
  Future<void> pumpRow(WidgetTester tester, List<AppliedWallpaper> items) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: RecentlySetRow(items: items)),
    ),
  );

  testWidgets('shows nothing when no wallpaper was set yet', (tester) async {
    await pumpRow(tester, const <AppliedWallpaper>[]);

    expect(find.text('Recently set'), findsNothing);
  });

  testWidgets('shows each wallpaper once, newest first, at most eight', (tester) async {
    await pumpRow(tester, <AppliedWallpaper>[
      for (int i = 0; i < 12; i++) _item('w$i'),
      _item('dup', fullUrl: 'https://example.com/w0.jpg'),
    ]);

    expect(find.text('Recently set'), findsOneWidget);
    expect(find.bySemanticsLabel('Set this wallpaper again'), findsAtLeastNWidgets(1));
    expect(find.byType(InkWell), findsNWidgets(8));
  });
}
